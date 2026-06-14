import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('ling/calendar_notifications'),
          null,
        );
  });

  test('setApplicationBadgeCount forwards non-negative count on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    const channel = MethodChannel('ling/calendar_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await MethodChannelCalendarNotificationBridge().setApplicationBadgeCount(5);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'setApplicationBadgeCount');
    expect(calls.single.arguments, <String, Object?>{'count': 5});
  });

  test('setApplicationBadgeCount clamps negative counts', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    const channel = MethodChannel('ling/calendar_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await MethodChannelCalendarNotificationBridge().setApplicationBadgeCount(
      -1,
    );

    expect(calls.single.arguments, <String, Object?>{'count': 0});
  });
}
