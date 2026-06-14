class SingleFlight<T> {
  Future<T>? _inFlight;

  bool get isRunning => _inFlight != null;

  Future<T> run(Future<T> Function() operation) {
    final current = _inFlight;
    if (current != null) {
      return current;
    }

    final future = operation();
    _inFlight = future;
    future.then<void>(
      (_) {
        if (identical(_inFlight, future)) {
          _inFlight = null;
        }
      },
      onError: (_) {
        if (identical(_inFlight, future)) {
          _inFlight = null;
        }
      },
    );
    return future;
  }
}
