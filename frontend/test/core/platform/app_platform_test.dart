import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/core/platform/push_transport.dart';

void main() {
  test('native Ling bridges are enabled for iOS and HarmonyOS', () {
    expect(isNativeLingBridgeSupported(platform: AppPlatform.ios), isTrue);
    expect(isNativeLingBridgeSupported(platform: AppPlatform.ohos), isTrue);
    expect(isNativeLingBridgeSupported(platform: AppPlatform.web), isFalse);
    expect(isNativeLingBridgeSupported(platform: AppPlatform.android), isFalse);
  });

  test('push transport resolves iOS APNs and HarmonyOS push', () {
    final ios = resolvePushTransportInfo(platform: AppPlatform.ios);
    final ohos = resolvePushTransportInfo(platform: AppPlatform.ohos);

    expect(ios.platform, 'ios');
    expect(ios.transport, 'apns');
    expect(ohos.platform, 'ohos');
    expect(ohos.transport, 'harmony_push');
  });

  test('push transport preserves native registration transport', () {
    final ohos = resolvePushTransportInfo(
      platform: AppPlatform.ohos,
      registrationTransport: ' custom_push ',
    );

    expect(ohos.platform, 'ohos');
    expect(ohos.transport, 'custom_push');
  });
}
