import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/analytics/analytics_repository.dart';
import 'package:ling/src/core/analytics/analytics_tracker.dart';
import 'package:ling/src/core/database/app_database.dart';
import 'package:ling/src/core/network/api_client.dart';
import 'package:ling/src/core/network/api_response.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'uploads queued analytics events and sanitizes sensitive fields',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final apiClient = _FakeApiClient();
      final tracker = AnalyticsTracker(
        database: database,
        repository: AnalyticsRepository(apiClient: apiClient),
        pushDeviceIdStore: PushDeviceIdStore(
          preferencesStore: const PreferencesStore(),
          idGenerator: () => 'device-1',
        ),
      );
      addTearDown(tracker.dispose);

      await tracker.track(
        'chat.prompt.submit',
        surface: 'chat',
        action: 'prompt_submit',
        source: 'keyboard',
        properties: <String, Object?>{
          'attachment_count': 1,
          'prompt': 'private prompt',
          'nested': <String, Object?>{'title': 'private title', 'mode': 'week'},
          'long_value': 'x' * 200,
        },
      );
      await tracker.flush();

      expect(await database.readPendingAnalyticsEvents(), isEmpty);
      expect(apiClient.requests, hasLength(1));
      final event = apiClient.singleEvent;
      expect(event['event_name'], 'chat.prompt.submit');
      expect(event['device_id'], 'device-1');
      final properties = Map<String, Object?>.from(event['properties'] as Map);
      expect(properties['attachment_count'], 1);
      expect(properties, isNot(contains('prompt')));
      expect(Map<String, Object?>.from(properties['nested'] as Map), {
        'mode': 'week',
      });
      expect((properties['long_value'] as String).length, 128);
    },
  );

  test('keeps queued analytics events when upload fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final apiClient = _FakeApiClient()..shouldFail = true;
    final tracker = AnalyticsTracker(
      database: database,
      repository: AnalyticsRepository(apiClient: apiClient),
      pushDeviceIdStore: PushDeviceIdStore(
        preferencesStore: const PreferencesStore(),
        idGenerator: () => 'device-1',
      ),
    );
    addTearDown(tracker.dispose);

    await tracker.track('settings.surface.open', surface: 'settings');

    await expectLater(tracker.flush(), throwsA(isA<StateError>()));
    expect(await database.readPendingAnalyticsEvents(), hasLength(1));

    apiClient.shouldFail = false;
    await tracker.flush();

    expect(await database.readPendingAnalyticsEvents(), isEmpty);
  });

  test(
    'uploads analytics events on interval using captured occurrence time',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final apiClient = _FakeApiClient();
      final tracker = AnalyticsTracker(
        database: database,
        repository: AnalyticsRepository(apiClient: apiClient),
        pushDeviceIdStore: PushDeviceIdStore(
          preferencesStore: const PreferencesStore(),
          idGenerator: () => 'device-1',
        ),
        flushInterval: const Duration(milliseconds: 30),
      );
      addTearDown(tracker.dispose);

      final firstBefore = DateTime.now().toUtc();
      await tracker.track('chat.quick_prompt.tap', surface: 'chat');
      final firstAfter = DateTime.now().toUtc();
      await tracker.track('chat.prompt.submit', surface: 'chat');

      expect(apiClient.requests, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(apiClient.requests, hasLength(1));
      expect(apiClient.events, hasLength(2));
      final occurredAt = DateTime.parse(
        apiClient.events.first['occurred_at'] as String,
      );
      expect(occurredAt.isBefore(firstBefore), isFalse);
      expect(occurredAt.isAfter(firstAfter), isFalse);
    },
  );
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient();

  final List<Object?> requests = <Object?>[];
  bool shouldFail = false;

  Map<String, Object?> get singleEvent {
    return events.single;
  }

  List<Map<String, Object?>> get events {
    final body = requests.single as Map<String, Object?>;
    final events = body['events'] as List;
    return events
        .map((event) => Map<String, Object?>.from(event as Map))
        .toList(growable: false);
  }

  @override
  Future<ApiResponse> post(String path, {Object? body}) async {
    if (path != '/analytics/events') {
      throw StateError('unexpected path: $path');
    }
    if (shouldFail) {
      throw StateError('offline');
    }
    requests.add(body);
    final events = (body as Map<String, Object?>)['events'] as List;
    return ApiResponse(
      code: 200,
      message: '',
      data: <String, Object?>{
        'accepted': events.length,
        'received': events.length,
        'duplicates': 0,
      },
      timestamp: null,
    );
  }
}
