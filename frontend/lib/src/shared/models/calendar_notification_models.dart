enum CalendarNotificationDeliveryChannel { lingLocal, appleCalendarWhenSynced }

enum CalendarNotificationDeliveryMode { bannerSound, bannerOnly, silent }

enum CalendarNotificationPermissionState {
  granted,
  denied,
  notDetermined,
  unsupported,
}

class ForegroundRemoteNotificationEvent {
  const ForegroundRemoteNotificationEvent({
    required this.identifier,
    required this.kind,
    this.mode,
    this.notificationId,
    this.targetType,
    this.targetId,
    this.targetAction,
  });

  final String identifier;
  final String kind;
  final String? mode;
  final String? notificationId;
  final String? targetType;
  final String? targetId;
  final String? targetAction;

  factory ForegroundRemoteNotificationEvent.fromJson(
    Map<Object?, Object?> json,
  ) {
    final mode = '${json['mode'] ?? ''}'.trim();
    return ForegroundRemoteNotificationEvent(
      identifier: '${json['identifier'] ?? ''}',
      kind: '${json['kind'] ?? ''}',
      mode: mode.isEmpty ? null : mode,
      notificationId: _trimmedOrNull(json['notification_id']),
      targetType: _trimmedOrNull(json['target_type']),
      targetId: _trimmedOrNull(json['target_id']),
      targetAction: _trimmedOrNull(json['target_action']),
    );
  }

  static String? _trimmedOrNull(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }
}

class CalendarNotificationSettings {
  const CalendarNotificationSettings({
    this.enabled = true,
    this.deliveryChannel = CalendarNotificationDeliveryChannel.lingLocal,
    this.deliveryMode = CalendarNotificationDeliveryMode.bannerSound,
    this.minutesBefore = 15,
    this.notifyAtStart = true,
  });

  final bool enabled;
  final CalendarNotificationDeliveryChannel deliveryChannel;
  final CalendarNotificationDeliveryMode deliveryMode;
  final int minutesBefore;
  final bool notifyAtStart;

  factory CalendarNotificationSettings.fromJson(Map<String, dynamic> json) {
    final rawMode = '${json['delivery_mode'] ?? 'banner_sound'}';
    final rawMinutes = int.tryParse('${json['minutes_before'] ?? 15}') ?? 15;
    final minutes = calendarNotificationMinuteOptions.contains(rawMinutes)
        ? rawMinutes
        : 15;
    return CalendarNotificationSettings(
      enabled: json['enabled'] == true,
      deliveryChannel: CalendarNotificationDeliveryChannel.lingLocal,
      deliveryMode: switch (rawMode) {
        'banner_only' => CalendarNotificationDeliveryMode.bannerOnly,
        'silent' => CalendarNotificationDeliveryMode.silent,
        _ => CalendarNotificationDeliveryMode.bannerSound,
      },
      minutesBefore: minutes,
      notifyAtStart: json['notify_at_start'] != false,
    );
  }

  CalendarNotificationSettings copyWith({
    bool? enabled,
    CalendarNotificationDeliveryChannel? deliveryChannel,
    CalendarNotificationDeliveryMode? deliveryMode,
    int? minutesBefore,
    bool? notifyAtStart,
  }) {
    return CalendarNotificationSettings(
      enabled: enabled ?? this.enabled,
      deliveryChannel: deliveryChannel ?? this.deliveryChannel,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      notifyAtStart: notifyAtStart ?? this.notifyAtStart,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'delivery_channel': 'ling_local',
      'delivery_mode': switch (deliveryMode) {
        CalendarNotificationDeliveryMode.bannerSound => 'banner_sound',
        CalendarNotificationDeliveryMode.bannerOnly => 'banner_only',
        CalendarNotificationDeliveryMode.silent => 'silent',
      },
      'minutes_before': minutesBefore,
      'notify_at_start': notifyAtStart,
    };
  }
}

const List<int> calendarNotificationMinuteOptions = [5, 10, 15, 30, 60];

class CalendarSyncSettings {
  const CalendarSyncSettings({this.appleWriteBackEnabled = false});

  final bool appleWriteBackEnabled;

  factory CalendarSyncSettings.fromJson(Map<String, dynamic> json) {
    return CalendarSyncSettings(
      appleWriteBackEnabled: json['apple_write_back_enabled'] == true,
    );
  }

  CalendarSyncSettings copyWith({bool? appleWriteBackEnabled}) {
    return CalendarSyncSettings(
      appleWriteBackEnabled:
          appleWriteBackEnabled ?? this.appleWriteBackEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {'apple_write_back_enabled': appleWriteBackEnabled};
  }
}
