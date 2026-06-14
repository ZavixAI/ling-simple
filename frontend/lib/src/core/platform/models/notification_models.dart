class CalendarNotificationRequest {
  const CalendarNotificationRequest({
    required this.identifier,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.mode,
    required this.soundEnabled,
  });

  final String identifier;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String mode;
  final bool soundEnabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'identifier': identifier,
      'title': title,
      'body': body,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'mode': mode,
      'soundEnabled': soundEnabled,
    };
  }
}

class RemoteNotificationRegistration {
  const RemoteNotificationRegistration({
    required this.pushToken,
    this.transport,
    this.provider,
    this.appId,
    this.appBundleId,
    this.apnsEnvironment,
  });

  final String pushToken;
  final String? transport;
  final String? provider;
  final String? appId;
  final String? appBundleId;
  final String? apnsEnvironment;

  factory RemoteNotificationRegistration.fromJson(Map<String, dynamic> json) {
    return RemoteNotificationRegistration(
      pushToken: '${json['push_token'] ?? ''}'.trim(),
      transport: '${json['transport'] ?? ''}'.trim(),
      provider: '${json['provider'] ?? ''}'.trim(),
      appId: '${json['app_id'] ?? ''}'.trim(),
      appBundleId: '${json['app_bundle_id'] ?? ''}'.trim(),
      apnsEnvironment: '${json['apns_environment'] ?? ''}'.trim(),
    );
  }
}

class DeviceContextSnapshot {
  const DeviceContextSnapshot({
    required this.timezone,
    this.deviceModel,
    this.formattedAddress,
    this.name,
    this.thoroughfare,
    this.subThoroughfare,
    this.subLocality,
    this.locality,
    this.subAdministrativeArea,
    this.city,
    this.administrativeArea,
    this.postalCode,
    this.country,
    this.isoCountryCode,
    this.areasOfInterest,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
  });

  final String timezone;
  final String? deviceModel;
  final String? formattedAddress;
  final String? name;
  final String? thoroughfare;
  final String? subThoroughfare;
  final String? subLocality;
  final String? locality;
  final String? subAdministrativeArea;
  final String? city;
  final String? administrativeArea;
  final String? postalCode;
  final String? country;
  final String? isoCountryCode;
  final List<String>? areasOfInterest;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;

  factory DeviceContextSnapshot.fromJson(Map<String, dynamic> json) {
    return DeviceContextSnapshot(
      timezone: '${json['timezone'] ?? ''}'.trim(),
      deviceModel: _optionalJsonString(json['device_model']),
      formattedAddress: _optionalJsonString(json['formatted_address']),
      name: _optionalJsonString(json['name']),
      thoroughfare: _optionalJsonString(json['thoroughfare']),
      subThoroughfare: _optionalJsonString(json['sub_thoroughfare']),
      subLocality: _optionalJsonString(json['sub_locality']),
      locality: _optionalJsonString(json['locality']),
      subAdministrativeArea: _optionalJsonString(
        json['sub_administrative_area'],
      ),
      city: '${json['city'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['city']}'.trim(),
      administrativeArea: '${json['administrative_area'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['administrative_area']}'.trim(),
      postalCode: _optionalJsonString(json['postal_code']),
      country: '${json['country'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['country']}'.trim(),
      isoCountryCode: _optionalJsonString(json['iso_country_code']),
      areasOfInterest: json['areas_of_interest'] is List
          ? (json['areas_of_interest'] as List)
                .map((item) => '$item'.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
      capturedAt: json['captured_at'] == null
          ? null
          : DateTime.tryParse('${json['captured_at']}'),
    );
  }
}

String? _optionalJsonString(Object? value) {
  final normalized = '${value ?? ''}'.trim();
  return normalized.isEmpty ? null : normalized;
}

enum DeviceLocationPermissionState {
  authorizedWhenInUse,
  authorizedAlways,
  notDetermined,
  denied,
  restricted,
  unsupported,
  unknown,
}

String serializeDeviceLocationPermissionState(
  DeviceLocationPermissionState state,
) {
  switch (state) {
    case DeviceLocationPermissionState.authorizedWhenInUse:
      return 'authorized_when_in_use';
    case DeviceLocationPermissionState.authorizedAlways:
      return 'authorized_always';
    case DeviceLocationPermissionState.notDetermined:
      return 'not_determined';
    case DeviceLocationPermissionState.denied:
      return 'denied';
    case DeviceLocationPermissionState.restricted:
      return 'restricted';
    case DeviceLocationPermissionState.unsupported:
      return 'unsupported';
    case DeviceLocationPermissionState.unknown:
      return 'unknown';
  }
}

DeviceLocationPermissionState deserializeDeviceLocationPermissionState(
  String? value,
) {
  switch (value) {
    case 'authorized_when_in_use':
      return DeviceLocationPermissionState.authorizedWhenInUse;
    case 'authorized_always':
      return DeviceLocationPermissionState.authorizedAlways;
    case 'not_determined':
      return DeviceLocationPermissionState.notDetermined;
    case 'denied':
      return DeviceLocationPermissionState.denied;
    case 'restricted':
      return DeviceLocationPermissionState.restricted;
    case 'unsupported':
      return DeviceLocationPermissionState.unsupported;
    default:
      return DeviceLocationPermissionState.unknown;
  }
}

class PushDeviceRegistrationRequest {
  const PushDeviceRegistrationRequest({
    required this.deviceId,
    required this.platform,
    required this.transport,
    required this.pushToken,
    this.appBundleId,
    this.apnsEnvironment,
    this.locale,
    this.timezone,
    this.deviceModel,
    this.formattedAddress,
    this.name,
    this.thoroughfare,
    this.subThoroughfare,
    this.subLocality,
    this.locality,
    this.subAdministrativeArea,
    this.city,
    this.administrativeArea,
    this.postalCode,
    this.country,
    this.isoCountryCode,
    this.areasOfInterest,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
    this.notificationsEnabled = true,
  });

  final String deviceId;
  final String platform;
  final String transport;
  final String pushToken;
  final String? appBundleId;
  final String? apnsEnvironment;
  final String? locale;
  final String? timezone;
  final String? deviceModel;
  final String? formattedAddress;
  final String? name;
  final String? thoroughfare;
  final String? subThoroughfare;
  final String? subLocality;
  final String? locality;
  final String? subAdministrativeArea;
  final String? city;
  final String? administrativeArea;
  final String? postalCode;
  final String? country;
  final String? isoCountryCode;
  final List<String>? areasOfInterest;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final bool notificationsEnabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'device_id': deviceId,
      'platform': platform,
      'transport': transport,
      'push_token': pushToken,
      'app_bundle_id': appBundleId,
      'apns_environment': apnsEnvironment,
      'locale': locale,
      'timezone': timezone,
      'device_model': deviceModel,
      'formatted_address': formattedAddress,
      'name': name,
      'thoroughfare': thoroughfare,
      'sub_thoroughfare': subThoroughfare,
      'sub_locality': subLocality,
      'locality': locality,
      'sub_administrative_area': subAdministrativeArea,
      'city': city,
      'administrative_area': administrativeArea,
      'postal_code': postalCode,
      'country': country,
      'iso_country_code': isoCountryCode,
      'areas_of_interest': areasOfInterest,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'captured_at': capturedAt?.toUtc().toIso8601String(),
      'notifications_enabled': notificationsEnabled,
    };
  }
}

class PushDeviceContextUpdateRequest {
  const PushDeviceContextUpdateRequest({
    required this.deviceId,
    required this.pushToken,
    this.timezone,
    this.deviceModel,
    this.formattedAddress,
    this.name,
    this.thoroughfare,
    this.subThoroughfare,
    this.subLocality,
    this.locality,
    this.subAdministrativeArea,
    this.city,
    this.administrativeArea,
    this.postalCode,
    this.country,
    this.isoCountryCode,
    this.areasOfInterest,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
  });

  final String deviceId;
  final String pushToken;
  final String? timezone;
  final String? deviceModel;
  final String? formattedAddress;
  final String? name;
  final String? thoroughfare;
  final String? subThoroughfare;
  final String? subLocality;
  final String? locality;
  final String? subAdministrativeArea;
  final String? city;
  final String? administrativeArea;
  final String? postalCode;
  final String? country;
  final String? isoCountryCode;
  final List<String>? areasOfInterest;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'device_id': deviceId,
      'push_token': pushToken,
      'timezone': timezone,
      'device_model': deviceModel,
      'formatted_address': formattedAddress,
      'name': name,
      'thoroughfare': thoroughfare,
      'sub_thoroughfare': subThoroughfare,
      'sub_locality': subLocality,
      'locality': locality,
      'sub_administrative_area': subAdministrativeArea,
      'city': city,
      'administrative_area': administrativeArea,
      'postal_code': postalCode,
      'country': country,
      'iso_country_code': isoCountryCode,
      'areas_of_interest': areasOfInterest,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'captured_at': capturedAt?.toUtc().toIso8601String(),
    };
  }
}

class AppBadgeCount {
  const AppBadgeCount({
    required this.total,
    required this.unreadNotificationCount,
    required this.attentionIntentCount,
    required this.cap,
  });

  final int total;
  final int unreadNotificationCount;
  final int attentionIntentCount;
  final int cap;

  factory AppBadgeCount.fromJson(Map<String, dynamic> json) {
    return AppBadgeCount(
      total: _readInt(json['total']),
      unreadNotificationCount: _readInt(json['unread_notification_count']),
      attentionIntentCount: _readInt(json['attention_intent_count']),
      cap: _readInt(json['cap']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}
