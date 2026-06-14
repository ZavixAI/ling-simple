import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/async/single_flight.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/calendar/application/calendar_controller.dart';
import 'package:ling/src/features/calendar/application/calendar_notification_support.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/data/repositories/apple_calendar_sync_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_repository.dart';
import 'package:ling/src/features/calendar/models/calendar_time.dart';
import 'package:ling/src/features/membership/application/membership_controller.dart';
import 'package:ling/src/features/membership/models/membership_models.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

class AppSessionLifecycleCoordinator {
  AppSessionLifecycleCoordinator(this._ref);

  final Ref _ref;
  final SingleFlight<void> _notificationScheduleSingleFlight =
      SingleFlight<void>();

  CalendarController get _calendarController =>
      _ref.read(calendarControllerProvider.notifier);
  CalendarRepository get _calendarRepository =>
      _ref.read(calendarRepositoryProvider);
  CalendarNotificationBridge get _notificationBridge =>
      _ref.read(calendarNotificationBridgeProvider);
  PushDeviceIdStore get _pushDeviceIdStore =>
      _ref.read(pushDeviceIdStoreProvider);
  AppleCalendarSyncRepository get _appleCalendarSyncRepository =>
      _ref.read(appleCalendarSyncRepositoryProvider);
  AppleCalendarBridge get _appleCalendarBridge =>
      _ref.read(appleCalendarBridgeProvider);

  Future<void> clearUserScopedLocalCaches() {
    return _calendarRepository.clearCalendarCache();
  }

  Future<void> syncCalendarNotificationSchedule({
    required bool isAuthenticated,
    required String timezone,
    required CalendarNotificationPermissionState permission,
    required CalendarNotificationSettings settings,
    required LingStrings strings,
    bool rethrowOnFailure = false,
  }) {
    if (!isAuthenticated) {
      return Future<void>.value();
    }
    return _notificationScheduleSingleFlight.run(() async {
      try {
        if (permission != CalendarNotificationPermissionState.granted) {
          await _notificationBridge.cancelAllNotifications();
          return;
        }
        if (!settings.enabled) {
          await _notificationBridge.cancelAllNotifications();
          return;
        }
        final startAt = currentLingDateTime(timezone);
        final endAt = startAt.add(const Duration(days: 30));
        final normalizedStartAt = normalizeLingDateTimeToMinute(startAt);
        final normalizedEndAt = normalizeLingDateTimeToMinute(endAt);
        final events = await _calendarController.getEventsInWindow(
          startAt: formatLingDateTimeWithTimezone(normalizedStartAt, timezone),
          endAt: formatLingDateTimeWithTimezone(normalizedEndAt, timezone),
          timezone: timezone,
        );
        await _notificationBridge.syncNotifications(
          buildCalendarNotificationRequests(
            events: events,
            strings: strings,
            settings: settings,
          ),
        );
      } catch (error, stackTrace) {
        AppLogger.warn(
          '[Ling][AppLifecycle] 日历通知同步失败',
          category: 'app',
          fields: <String, Object?>{'error': '$error'},
        );
        AppLogger.debug('$stackTrace', category: 'app');
        if (rethrowOnFailure) {
          rethrow;
        }
      }
    });
  }

  Future<void> cleanupBeforeSessionEnd({
    required bool isAuthenticated,
    String? deviceId,
    bool removeRemotePushDevice = true,
  }) async {
    final resolvedDeviceId = await _resolveDeviceId(deviceId);
    await cleanupManagedAppleCalendarEvents(deviceId: resolvedDeviceId);
    if (removeRemotePushDevice) {
      await removeRemotePushDeviceRegistration(
        isAuthenticated: isAuthenticated,
        deviceId: resolvedDeviceId,
      );
    }
    await cancelCalendarNotifications();
    await _notificationBridge.setApplicationBadgeCount(0);
  }

  Future<void> removeRemotePushDeviceRegistration({
    required bool isAuthenticated,
    String? deviceId,
  }) async {
    if (!isAuthenticated) {
      return;
    }
    final resolvedDeviceId = await _resolveDeviceId(deviceId);
    if (resolvedDeviceId.isEmpty) {
      return;
    }
    try {
      await _ref
          .read(profileRepositoryProvider)
          .deletePushDevice(resolvedDeviceId);
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][AppLifecycle] 删除远端推送设备失败',
        category: 'app',
        fields: <String, Object?>{
          'device_id': resolvedDeviceId,
          'error': '$error',
        },
      );
      AppLogger.debug('$stackTrace', category: 'app');
    }
  }

  Future<void> cleanupManagedAppleCalendarEvents({String? deviceId}) async {
    final resolvedDeviceId = await _resolveDeviceId(deviceId);
    if (resolvedDeviceId.isEmpty) {
      return;
    }
    try {
      final links = await _appleCalendarSyncRepository.getManagedAppleLinks(
        resolvedDeviceId,
      );
      if (links.isEmpty) {
        return;
      }
      await _appleCalendarBridge.deleteManagedEvents(links);
      await _appleCalendarSyncRepository.deleteManagedAppleLinks(
        resolvedDeviceId,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][AppLifecycle] 托管的 Apple 日历清理失败',
        category: 'app',
        fields: <String, Object?>{
          'device_id': resolvedDeviceId,
          'error': '$error',
        },
      );
      AppLogger.debug('$stackTrace', category: 'app');
    }
  }

  Future<void> cancelCalendarNotifications() {
    return _notificationBridge.cancelAllNotifications();
  }

  Future<void> syncApplicationBadge({required bool isAuthenticated}) async {
    try {
      if (!isAuthenticated) {
        await _notificationBridge.setApplicationBadgeCount(0);
        return;
      }
      final badge = await _ref.read(profileRepositoryProvider).getBadgeCount();
      await _notificationBridge.setApplicationBadgeCount(badge.total);
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][AppLifecycle] 同步 App badge 失败',
        category: 'app',
        fields: <String, Object?>{'error': '$error'},
      );
      AppLogger.debug('$stackTrace', category: 'app');
    }
  }

  Future<void> markAllBadgeNotificationsRead({
    required bool isAuthenticated,
  }) async {
    try {
      if (!isAuthenticated) {
        await _notificationBridge.setApplicationBadgeCount(0);
        return;
      }
      final badge = await _ref
          .read(profileRepositoryProvider)
          .markAllBadgeNotificationsRead();
      await _notificationBridge.setApplicationBadgeCount(badge.total);
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][AppLifecycle] 清理 App badge 通知已读失败',
        category: 'app',
        fields: <String, Object?>{'error': '$error'},
      );
      AppLogger.debug('$stackTrace', category: 'app');
    }
  }

  Future<void> markNotificationOpened({
    required bool isAuthenticated,
    required String notificationId,
  }) async {
    final normalizedNotificationId = notificationId.trim();
    if (!isAuthenticated || normalizedNotificationId.isEmpty) {
      return;
    }
    try {
      final badge = await _ref
          .read(profileRepositoryProvider)
          .markNotificationOpened(normalizedNotificationId);
      await _notificationBridge.setApplicationBadgeCount(badge.total);
    } catch (error, stackTrace) {
      AppLogger.warn(
        '[Ling][AppLifecycle] 标记通知已打开失败',
        category: 'app',
        fields: <String, Object?>{
          'notification_id': normalizedNotificationId,
          'error': '$error',
        },
      );
      AppLogger.debug('$stackTrace', category: 'app');
    }
  }

  Future<bool> ensureMembershipReadyForChat({
    required bool isAuthenticated,
    required void Function(Object error) onError,
  }) async {
    if (!isAuthenticated) {
      return true;
    }
    var membershipState = _ref.read(membershipControllerProvider);
    if (membershipState.summary != null) {
      return true;
    }
    if (membershipState.isLoadingSummary) {
      final didLoadDuringWait = await _waitForMembershipSummaryLoad();
      membershipState = _ref.read(membershipControllerProvider);
      if (didLoadDuringWait && membershipState.summary != null) {
        return true;
      }
    }
    try {
      await _ref.read(membershipControllerProvider.notifier).refreshSummary();
    } catch (error) {
      onError(error);
      return false;
    }
    return _ref.read(membershipControllerProvider).summary != null;
  }

  void applyQuotaSummary(MembershipSummary? summary) {
    if (summary == null) {
      return;
    }
    _ref.read(membershipControllerProvider.notifier).applyQuotaSummary(summary);
  }

  Future<bool> _waitForMembershipSummaryLoad() async {
    const timeout = Duration(seconds: 2);
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final membershipState = _ref.read(membershipControllerProvider);
      if (!membershipState.isLoadingSummary) {
        return membershipState.summary != null;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<String> _resolveDeviceId(String? deviceId) async {
    return ((deviceId ?? await _pushDeviceIdStore.read()) ?? '').trim();
  }
}

final appSessionLifecycleCoordinatorProvider =
    Provider<AppSessionLifecycleCoordinator>(
      AppSessionLifecycleCoordinator.new,
    );
