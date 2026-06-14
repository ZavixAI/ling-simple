import 'dart:convert';
import 'dart:math';

import 'package:ling/src/core/storage/preferences_store.dart';

class PushDeviceIdStore {
  PushDeviceIdStore({
    required PreferencesStore preferencesStore,
    String storageKey = defaultStorageKey,
    String Function() idGenerator = _generatePushDeviceId,
  }) : _preferencesStore = preferencesStore,
       _storageKey = storageKey,
       _idGenerator = idGenerator;

  static const String defaultStorageKey = 'ling.push_device_id';

  final PreferencesStore _preferencesStore;
  final String _storageKey;
  final String Function() _idGenerator;

  String? _cachedDeviceId;

  Future<String?> read() async {
    final cachedDeviceId = _cachedDeviceId;
    if (cachedDeviceId != null && cachedDeviceId.isNotEmpty) {
      return cachedDeviceId;
    }

    final storedDeviceId = (await _preferencesStore.readString(
      _storageKey,
    ))?.trim();
    if (storedDeviceId == null || storedDeviceId.isEmpty) {
      return null;
    }

    _cachedDeviceId = storedDeviceId;
    return storedDeviceId;
  }

  Future<String> getOrCreate() async {
    final storedDeviceId = await read();
    if (storedDeviceId != null) {
      return storedDeviceId;
    }

    final generatedDeviceId = _idGenerator();
    await _preferencesStore.writeString(_storageKey, generatedDeviceId);
    _cachedDeviceId = generatedDeviceId;
    return generatedDeviceId;
  }

  Future<void> replace(String deviceId) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      return;
    }
    _cachedDeviceId = normalizedDeviceId;
    await _preferencesStore.writeString(_storageKey, normalizedDeviceId);
  }

  Future<void> clear() async {
    _cachedDeviceId = null;
    await _preferencesStore.remove(_storageKey);
  }
}

String _generatePushDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
