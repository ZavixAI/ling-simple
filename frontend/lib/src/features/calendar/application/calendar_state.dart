import 'package:ling/src/features/calendar/models/calendar_models.dart';

class CalendarState {
  const CalendarState({
    required this.selectedDate,
    required this.selectedMonth,
    required this.timezone,
    this.isLoading = false,
    this.events = const <LingEvent>[],
    this.monthSnapshot,
    this.errorMessage,
  });

  final String selectedDate;
  final String selectedMonth;
  final String timezone;
  final bool isLoading;
  final List<LingEvent> events;
  final CalendarMonthSnapshot? monthSnapshot;
  final String? errorMessage;

  factory CalendarState.initial({
    required String selectedDate,
    required String selectedMonth,
    required String timezone,
  }) {
    return CalendarState(
      selectedDate: selectedDate,
      selectedMonth: selectedMonth,
      timezone: timezone,
    );
  }

  CalendarState copyWith({
    String? selectedDate,
    String? selectedMonth,
    String? timezone,
    bool? isLoading,
    List<LingEvent>? events,
    CalendarMonthSnapshot? monthSnapshot,
    bool clearMonthSnapshot = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      timezone: timezone ?? this.timezone,
      isLoading: isLoading ?? this.isLoading,
      events: events ?? this.events,
      monthSnapshot: clearMonthSnapshot
          ? null
          : (monthSnapshot ?? this.monthSnapshot),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
