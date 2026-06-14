import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/features/calendar/application/calendar_state.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_repository.dart';
import 'package:ling/src/features/calendar/models/calendar_models.dart';

class CalendarController extends Notifier<CalendarState> {
  CalendarRepository get _repository => ref.read(calendarRepositoryProvider);
  int _activeLoadRequestId = 0;

  @override
  CalendarState build() {
    final now = DateTime.now();
    return CalendarState.initial(
      selectedDate: _formatDate(now),
      selectedMonth: _formatMonth(now),
      timezone: 'UTC',
    );
  }

  void updateTimezone(String timezone) {
    final normalized = timezone.trim();
    if (normalized.isEmpty || normalized == state.timezone) {
      return;
    }
    state = state.copyWith(timezone: normalized);
  }

  void focusDate(DateTime value) {
    state = state.copyWith(
      selectedDate: _formatDate(value),
      selectedMonth: _formatMonth(value),
      clearErrorMessage: true,
    );
  }

  Future<void> selectDate(String date) async {
    final parsed = _parseDateOnly(date);
    state = state.copyWith(
      selectedDate: _formatDate(parsed),
      selectedMonth: _formatMonth(parsed),
      clearErrorMessage: true,
    );
    await load(forceRefresh: true);
  }

  Future<void> changeSelectedMonth(int delta) async {
    final current = _parseDateOnly(state.selectedDate);
    final targetMonth = DateTime(current.year, current.month + delta, 1);
    final lastDayOfTargetMonth = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
    ).day;
    final clampedDay = current.day <= lastDayOfTargetMonth
        ? current.day
        : lastDayOfTargetMonth;
    final nextSelectedDate = DateTime(
      targetMonth.year,
      targetMonth.month,
      clampedDay,
    );
    focusDate(nextSelectedDate);
    await load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    final snapshot = state;
    final requestId = ++_activeLoadRequestId;
    state = snapshot.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final results = await Future.wait<Object>([
        _repository.getEventsForDate(
          date: snapshot.selectedDate,
          timezone: snapshot.timezone,
          forceRefresh: forceRefresh,
        ),
        _repository.getMonth(
          month: snapshot.selectedMonth,
          timezone: snapshot.timezone,
          selectedDate: snapshot.selectedDate,
          forceRefresh: forceRefresh,
        ),
      ]);
      if (requestId != _activeLoadRequestId) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        events: List<LingEvent>.from(results[0] as List<LingEvent>),
        monthSnapshot: results[1] as CalendarMonthSnapshot,
        clearErrorMessage: true,
      );
    } catch (error) {
      if (requestId != _activeLoadRequestId) {
        return;
      }
      state = state.copyWith(isLoading: false, errorMessage: '$error');
      rethrow;
    }
  }

  Future<LingEvent> updateEvent(
    String eventId,
    LingEventUpsertRequest payload, {
    DateTime? nextFocusedDate,
  }) async {
    final event = await _repository.updateEvent(eventId, payload);
    if (nextFocusedDate != null) {
      focusDate(nextFocusedDate);
    }
    await load(forceRefresh: true);
    return event;
  }

  Future<void> deleteEvent(
    String eventId, {
    String scope = 'series',
    String? occurrenceStartTime,
  }) async {
    await _repository.deleteEvent(
      eventId,
      scope: scope,
      occurrenceStartTime: occurrenceStartTime,
    );
    await load(forceRefresh: true);
  }

  Future<List<LingEvent>> getEventsInWindow({
    required String startAt,
    required String endAt,
    required String timezone,
    bool forceRefresh = false,
  }) {
    return _repository.getEventsInWindow(
      startAt: startAt,
      endAt: endAt,
      timezone: timezone,
      forceRefresh: forceRefresh,
    );
  }

  void reset({String? timezone}) {
    final now = DateTime.now();
    state = CalendarState.initial(
      selectedDate: _formatDate(now),
      selectedMonth: _formatMonth(now),
      timezone: (timezone ?? state.timezone).trim().isEmpty
          ? 'UTC'
          : (timezone ?? state.timezone).trim(),
    );
  }

  DateTime _parseDateOnly(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      return DateTime.parse(value);
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return DateTime.parse(value);
    }
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatMonth(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$year-$month';
  }
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);
