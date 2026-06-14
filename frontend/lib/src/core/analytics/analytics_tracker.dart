import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:ling/src/config/app_environment.dart';
import 'package:ling/src/core/analytics/analytics_models.dart';
import 'package:ling/src/core/analytics/analytics_repository.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/logging/app_logger.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';

class AnalyticsTracker {
  AnalyticsTracker({
    required AppDatabase database,
    required AnalyticsRepository repository,
    required PushDeviceIdStore pushDeviceIdStore,
    Duration flushInterval = _defaultFlushInterval,
  }) : _database = database,
       _repository = repository,
       _pushDeviceIdStore = pushDeviceIdStore,
       _flushInterval = flushInterval;

  static const Duration _defaultFlushInterval = Duration(minutes: 1);
  static const int _uploadBatchSize = 100;
  static final Set<String> _sensitiveKeys = <String>{
    'body',
    'content',
    'description',
    'email',
    'message',
    'phone',
    'phonenum',
    'prompt',
    'text',
    'title',
    'transcript',
  };

  final AppDatabase _database;
  final AnalyticsRepository _repository;
  final PushDeviceIdStore _pushDeviceIdStore;
  final Duration _flushInterval;
  final Random _random = Random.secure();

  Timer? _flushTimer;
  Future<void> _operationQueue = Future<void>.value();
  String _clientSessionId = _nextSessionId();
  int _sequence = 0;

  void startNewClientSession() {
    _clientSessionId = _nextSessionId();
  }

  Future<void> track(
    String eventName, {
    String? surface,
    String? action,
    String? source,
    String? locale,
    String? timezone,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    final normalizedEventName = eventName.trim();
    if (normalizedEventName.isEmpty) {
      return Future<void>.value();
    }
    final occurredAt = DateTime.now();
    final future = _enqueueOperation(() async {
      final deviceId = await _pushDeviceIdStore.getOrCreate();
      final event = AnalyticsEvent(
        clientEventId: _nextEventId(),
        eventName: normalizedEventName,
        surface: _emptyToNull(surface),
        action: _emptyToNull(action),
        source: _emptyToNull(source),
        occurredAt: occurredAt,
        deviceId: deviceId,
        clientSessionId: _clientSessionId,
        platform: AppPlatformInfo.current.name,
        appVersion: AppEnvironment.appVersion,
        locale: _emptyToNull(locale),
        timezone: _emptyToNull(timezone),
        properties: _sanitizeProperties(properties),
      );
      await _database.enqueueAnalyticsEvent(
        id: event.clientEventId,
        payload: event.encode(),
      );
      _scheduleFlush();
    });
    return future;
  }

  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    return _enqueueOperation(_flushInternal);
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  Future<void> _enqueueOperation(Future<void> Function() operation) {
    final next = _operationQueue.then((_) => operation());
    _operationQueue = next.catchError((Object error, StackTrace stackTrace) {
      AppLogger.debug(
        '[Ling][Analytics] operation failed',
        category: 'analytics',
        fields: <String, Object?>{'error': '$error'},
      );
    });
    return next;
  }

  void _scheduleFlush() {
    if (_flushTimer != null) {
      return;
    }
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      unawaited(_flushScheduled());
    });
  }

  Future<void> _flushScheduled() async {
    try {
      await _enqueueOperation(_flushInternal);
    } catch (error) {
      AppLogger.debug(
        '[Ling][Analytics] scheduled flush failed',
        category: 'analytics',
        fields: <String, Object?>{'error': '$error'},
      );
    }
  }

  Future<void> _flushInternal() async {
    final rows = await _database.readPendingAnalyticsEvents(
      limit: _uploadBatchSize,
    );
    if (rows.isEmpty) {
      return;
    }
    final events = rows
        .map((row) => _repository.decode(row.payload))
        .toList(growable: false);
    await _repository.uploadEvents(events);
    await _database.deleteAnalyticsEventsByIds(
      rows.map((row) => row.id).toList(growable: false),
    );
  }

  String _nextEventId() {
    _sequence += 1;
    return 'ae_${DateTime.now().microsecondsSinceEpoch}_${_sequence}_${_random.nextInt(1 << 32)}';
  }

  static String _nextSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return 'acs_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  static String? _emptyToNull(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static Map<String, Object?> _sanitizeProperties(
    Map<String, Object?> properties,
  ) {
    final sanitized = <String, Object?>{};
    for (final entry in properties.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || _sensitiveKeys.contains(key.toLowerCase())) {
        continue;
      }
      sanitized[key.length > 64 ? key.substring(0, 64) : key] = _sanitizeValue(
        entry.value,
      );
    }
    return sanitized;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null || value is bool || value is num) {
      return value;
    }
    if (value is String) {
      return value.length > 128 ? value.substring(0, 128) : value;
    }
    if (value is Iterable) {
      return value.take(20).map(_sanitizeValue).toList(growable: false);
    }
    if (value is Map) {
      return _sanitizeProperties(
        value.map((key, item) => MapEntry('$key', item)),
      );
    }
    final text = '$value';
    return text.length > 128 ? text.substring(0, 128) : text;
  }
}
