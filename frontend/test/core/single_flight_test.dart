import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/async/single_flight.dart';

void main() {
  test('returns the same future while work is in flight', () async {
    final singleFlight = SingleFlight<int>();
    final completer = Completer<int>();
    var callCount = 0;

    Future<int> run() {
      return singleFlight.run(() {
        callCount += 1;
        return completer.future;
      });
    }

    final first = run();
    final second = run();

    expect(identical(first, second), isTrue);
    expect(callCount, 1);

    completer.complete(7);
    expect(await first, 7);
    expect(singleFlight.isRunning, isFalse);
  });

  test('accepts a new run after the previous future completes', () async {
    final singleFlight = SingleFlight<int>();
    var nextValue = 1;

    Future<int> run() {
      return singleFlight.run(() async => nextValue++);
    }

    expect(await run(), 1);
    expect(await run(), 2);
  });
}
