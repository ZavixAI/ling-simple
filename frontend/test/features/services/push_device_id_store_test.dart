import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/storage/preferences_store.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'returns the stored push device id before generating a new one',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PushDeviceIdStore.defaultStorageKey: 'stored-device',
      });
      final store = PushDeviceIdStore(
        preferencesStore: const PreferencesStore(),
        idGenerator: () => 'generated-device',
      );

      final deviceId = await store.getOrCreate();

      expect(deviceId, 'stored-device');
    },
  );

  test('persists a generated push device id and reuses it', () async {
    final store = PushDeviceIdStore(
      preferencesStore: const PreferencesStore(),
      idGenerator: () => 'generated-device',
    );
    await store.clear();

    final firstId = await store.getOrCreate();
    final secondId = await store.read();

    expect(firstId, 'generated-device');
    expect(secondId, 'generated-device');
  });

  test('replace overwrites the stored push device id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PushDeviceIdStore.defaultStorageKey: 'old-device',
    });
    final store = PushDeviceIdStore(
      preferencesStore: const PreferencesStore(),
      idGenerator: () => 'generated-device',
    );

    await store.replace('new-device');

    expect(await store.read(), 'new-device');
    expect(await store.getOrCreate(), 'new-device');
  });
}
