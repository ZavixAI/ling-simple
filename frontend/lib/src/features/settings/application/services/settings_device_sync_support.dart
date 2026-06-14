import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/platform/push_transport.dart';

String resolvePushRegistrationTimezone({
  required String fallbackTimezone,
  DeviceContextSnapshot? deviceContext,
}) {
  final contextTimezone = deviceContext?.timezone.trim() ?? '';
  if (contextTimezone.isNotEmpty) {
    return contextTimezone;
  }
  return fallbackTimezone;
}

PushDeviceRegistrationRequest buildPushDeviceRegistrationRequest({
  required String deviceId,
  required String locale,
  required String fallbackTimezone,
  required RemoteNotificationRegistration registration,
  DeviceContextSnapshot? deviceContext,
  bool includeLocationData = true,
  bool notificationsEnabled = true,
  AppPlatform? platform,
}) {
  final pushTransport = resolvePushTransportInfo(
    platform: platform,
    registrationTransport: registration.transport,
  );
  return PushDeviceRegistrationRequest(
    deviceId: deviceId,
    platform: pushTransport.platform,
    transport: pushTransport.transport,
    pushToken: registration.pushToken.trim(),
    appBundleId: registration.appBundleId?.trim(),
    apnsEnvironment: registration.apnsEnvironment?.trim(),
    locale: locale,
    timezone: resolvePushRegistrationTimezone(
      fallbackTimezone: fallbackTimezone,
      deviceContext: deviceContext,
    ),
    deviceModel: deviceContext?.deviceModel,
    formattedAddress: includeLocationData
        ? deviceContext?.formattedAddress
        : null,
    name: includeLocationData ? deviceContext?.name : null,
    thoroughfare: includeLocationData ? deviceContext?.thoroughfare : null,
    subThoroughfare: includeLocationData
        ? deviceContext?.subThoroughfare
        : null,
    subLocality: includeLocationData ? deviceContext?.subLocality : null,
    locality: includeLocationData ? deviceContext?.locality : null,
    subAdministrativeArea: includeLocationData
        ? deviceContext?.subAdministrativeArea
        : null,
    city: includeLocationData ? deviceContext?.city : null,
    administrativeArea: includeLocationData
        ? deviceContext?.administrativeArea
        : null,
    postalCode: includeLocationData ? deviceContext?.postalCode : null,
    country: includeLocationData ? deviceContext?.country : null,
    isoCountryCode: includeLocationData ? deviceContext?.isoCountryCode : null,
    areasOfInterest: includeLocationData
        ? deviceContext?.areasOfInterest
        : null,
    latitude: includeLocationData ? deviceContext?.latitude : null,
    longitude: includeLocationData ? deviceContext?.longitude : null,
    accuracyMeters: includeLocationData ? deviceContext?.accuracyMeters : null,
    capturedAt: includeLocationData ? deviceContext?.capturedAt : null,
    notificationsEnabled: notificationsEnabled,
  );
}
