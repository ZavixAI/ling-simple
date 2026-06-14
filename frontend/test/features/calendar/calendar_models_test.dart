import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

void main() {
  test('LingEvent parses point events without inventing a duration', () {
    final event = LingEvent.fromJson(<String, dynamic>{
      'event_id': 'evt_point',
      'user_id': 'user-1',
      'title': '提醒给爸妈打电话',
      'start_at': '2026-04-05T20:00:00+08:00',
      'end_at': '2026-04-05T20:00:00+08:00',
      'timezone': 'Asia/Shanghai',
      'time_shape': 'point',
      'metadata': <String, dynamic>{},
    });

    expect(event.isPoint, isTrue);
    expect(event.endAt, event.startAt);
    expect(event.toJson()['time_shape'], 'point');
    expect(event.toJson()['end_at'], event.toJson()['start_at']);
  });
}
