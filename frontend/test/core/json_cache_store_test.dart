import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/cache/json_cache_store.dart';
import 'package:ling/src/core/storage/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns cached value before ttl expires', () async {
    final now = DateTime(2026, 4, 4, 12);
    final store = JsonCacheStore(now: () => now);

    await store.write<Map<String, dynamic>>(
      'ling.test.profile',
      ttl: const Duration(minutes: 5),
      value: <String, dynamic>{'name': 'Ling'},
      encoder: (value) => value,
    );

    final cached = await store.read<Map<String, dynamic>>(
      'ling.test.profile',
      decoder: (value) => Map<String, dynamic>.from(value as Map),
    );

    expect(cached, isNotNull);
    expect(cached!['name'], 'Ling');
  });

  test('drops expired value from persistent cache', () async {
    final now = DateTime(2026, 4, 4, 12);
    var currentNow = now;
    final store = JsonCacheStore(now: () => currentNow);

    await store.write<Map<String, dynamic>>(
      'ling.test.expired',
      ttl: const Duration(minutes: 1),
      value: <String, dynamic>{'status': 'cached'},
      encoder: (value) => value,
    );

    currentNow = now.add(const Duration(minutes: 2));

    final cached = await store.read<Map<String, dynamic>>(
      'ling.test.expired',
      decoder: (value) => Map<String, dynamic>.from(value as Map),
    );

    expect(cached, isNull);

    final preferences = await AppPreferences.instance;
    expect(preferences.getString('ling.test.expired'), isNull);
  });

  test('deduplicates concurrent loads for the same key', () async {
    final store = JsonCacheStore();
    var loadCount = 0;

    final futures = <Future<Map<String, dynamic>>>[
      store.getOrLoad<Map<String, dynamic>>(
        'ling.test.concurrent',
        ttl: const Duration(minutes: 5),
        loader: () async {
          loadCount += 1;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return <String, dynamic>{'value': 1};
        },
        encoder: (value) => value,
        decoder: (value) => Map<String, dynamic>.from(value as Map),
      ),
      store.getOrLoad<Map<String, dynamic>>(
        'ling.test.concurrent',
        ttl: const Duration(minutes: 5),
        loader: () async {
          loadCount += 1;
          return <String, dynamic>{'value': 2};
        },
        encoder: (value) => value,
        decoder: (value) => Map<String, dynamic>.from(value as Map),
      ),
    ];

    final results = await Future.wait(futures);

    expect(loadCount, 1);
    expect(results[0]['value'], 1);
    expect(results[1]['value'], 1);
  });

  test(
    'mutating a cached nested value does not leak back into the cache',
    () async {
      final store = JsonCacheStore();

      await store.write<Map<String, dynamic>>(
        'ling.test.nested',
        ttl: const Duration(minutes: 5),
        value: <String, dynamic>{
          'profile': <String, dynamic>{
            'name': 'Ling',
            'tags': <String>['focus', 'calendar'],
          },
        },
        encoder: (value) => value,
      );

      final firstRead = await store.read<Map<String, dynamic>>(
        'ling.test.nested',
        decoder: (value) => Map<String, dynamic>.from(value as Map),
      );
      final firstProfile = Map<String, dynamic>.from(
        firstRead!['profile'] as Map,
      );
      final firstTags = List<String>.from(firstProfile['tags'] as List);
      firstTags.add('mutated');
      firstProfile['tags'] = firstTags;
      firstRead['profile'] = firstProfile;

      final secondRead = await store.read<Map<String, dynamic>>(
        'ling.test.nested',
        decoder: (value) => Map<String, dynamic>.from(value as Map),
      );
      final secondProfile = Map<String, dynamic>.from(
        secondRead!['profile'] as Map,
      );

      expect(secondProfile['name'], 'Ling');
      expect(secondProfile['tags'], <String>['focus', 'calendar']);
    },
  );
}
