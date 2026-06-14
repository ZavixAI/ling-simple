import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';

class HomeSurfaceState {
  const HomeSurfaceState({
    this.applePermission = AppleCalendarPermissionState.notDetermined,
    this.appleEvents = const <AppleCalendarEvent>[],
    this.calendarConnections = const <CalendarConnectionSummary>[],
    this.hasLoadedSchedulePageData = false,
    this.hasLoadedSettingsPageData = false,
  });

  final AppleCalendarPermissionState applePermission;
  final List<AppleCalendarEvent> appleEvents;
  final List<CalendarConnectionSummary> calendarConnections;
  final bool hasLoadedSchedulePageData;
  final bool hasLoadedSettingsPageData;

  HomeSurfaceState copyWith({
    AppleCalendarPermissionState? applePermission,
    List<AppleCalendarEvent>? appleEvents,
    List<CalendarConnectionSummary>? calendarConnections,
    bool? hasLoadedSchedulePageData,
    bool? hasLoadedSettingsPageData,
  }) {
    return HomeSurfaceState(
      applePermission: applePermission ?? this.applePermission,
      appleEvents: appleEvents ?? this.appleEvents,
      calendarConnections: calendarConnections ?? this.calendarConnections,
      hasLoadedSchedulePageData:
          hasLoadedSchedulePageData ?? this.hasLoadedSchedulePageData,
      hasLoadedSettingsPageData:
          hasLoadedSettingsPageData ?? this.hasLoadedSettingsPageData,
    );
  }
}
