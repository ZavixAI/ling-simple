typedef JsonDecoder<T> = T Function(Object? value);
typedef JsonEncoder<T> = Object? Function(T value);

class JsonCacheStore {
  JsonCacheStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, _CachedJsonValue> _memoryCache =
      <String, _CachedJsonValue>{};
  final Map<String, Future<Object?>> _inFlightLoads =
      <String, Future<Object?>>{};

  Future<T?> read<T>(String key, {required JsonDecoder<T> decoder}) async {
    final cached = _memoryCache[key];
    final now = _now();
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return decoder(_cloneJsonValue(cached.payload));
    }
    _memoryCache.remove(key);
    return null;
  }

  Future<void> write<T>(
    String key, {
    required Duration ttl,
    required T value,
    required JsonEncoder<T> encoder,
  }) async {
    final payload = _cloneJsonValue(encoder(value));
    final expiresAt = _now().add(ttl);
    _memoryCache[key] = _CachedJsonValue(
      expiresAt: expiresAt,
      payload: payload,
    );
  }

  Future<T> getOrLoad<T>(
    String key, {
    required Duration ttl,
    required Future<T> Function() loader,
    required JsonDecoder<T> decoder,
    required JsonEncoder<T> encoder,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await read<T>(key, decoder: decoder);
      if (cached != null) {
        return cached;
      }
    }

    final inFlight = _inFlightLoads[key];
    if (inFlight != null) {
      final payload = await inFlight;
      return decoder(_cloneJsonValue(payload));
    }

    final loadFuture = () async {
      final value = await loader();
      final payload = _cloneJsonValue(encoder(value));
      await write<Object?>(
        key,
        ttl: ttl,
        value: payload,
        encoder: (cachedValue) => cachedValue,
      );
      return payload;
    }();

    _inFlightLoads[key] = loadFuture;
    try {
      final payload = await loadFuture;
      return decoder(_cloneJsonValue(payload));
    } finally {
      if (identical(_inFlightLoads[key], loadFuture)) {
        _inFlightLoads.remove(key);
      }
    }
  }

  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    _inFlightLoads.remove(key);
  }

  Future<void> invalidatePrefix(String prefix) async {
    final keys = _memoryCache.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in keys) {
      _memoryCache.remove(key);
      _inFlightLoads.remove(key);
    }
  }

  Object? _cloneJsonValue(Object? value) {
    if (value is List) {
      return value
          .map<Object?>((item) => _cloneJsonValue(item))
          .toList(growable: false);
    }
    if (value is Map) {
      final clonedEntries = value.entries
          .map((entry) => MapEntry(entry.key, _cloneJsonValue(entry.value)))
          .toList(growable: false);
      if (clonedEntries.every((entry) => entry.key is String)) {
        return Map<String, dynamic>.fromEntries(
          clonedEntries.map(
            (entry) => MapEntry(entry.key as String, entry.value),
          ),
        );
      }
      return Map<Object?, Object?>.fromEntries(clonedEntries);
    }
    return value;
  }
}

class _CachedJsonValue {
  const _CachedJsonValue({required this.expiresAt, required this.payload});

  final DateTime expiresAt;
  final Object? payload;
}
