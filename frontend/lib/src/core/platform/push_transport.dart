import 'package:ling/src/core/platform/app_platform.dart';

class PushTransportInfo {
  const PushTransportInfo({required this.platform, required this.transport});

  final String platform;
  final String transport;
}

PushTransportInfo resolvePushTransportInfo({
  AppPlatform? platform,
  String? registrationTransport,
}) {
  final current = platform ?? AppPlatformInfo.current;
  final normalizedRegistrationTransport = (registrationTransport ?? '').trim();
  switch (current) {
    case AppPlatform.ohos:
      return PushTransportInfo(
        platform: current.name,
        transport: normalizedRegistrationTransport.isEmpty
            ? 'harmony_push'
            : normalizedRegistrationTransport,
      );
    case AppPlatform.ios:
      return PushTransportInfo(
        platform: current.name,
        transport: normalizedRegistrationTransport.isEmpty
            ? 'apns'
            : normalizedRegistrationTransport,
      );
    case AppPlatform.web:
    case AppPlatform.android:
    case AppPlatform.macos:
    case AppPlatform.windows:
    case AppPlatform.linux:
    case AppPlatform.fuchsia:
    case AppPlatform.unknown:
      return PushTransportInfo(
        platform: current.name,
        transport: normalizedRegistrationTransport,
      );
  }
}
