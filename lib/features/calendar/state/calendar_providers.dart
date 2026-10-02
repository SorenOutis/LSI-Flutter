import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/domain/dashboard_data.dart';
import '../../dashboard/state/dashboard_providers.dart';
import '../domain/calendar_data.dart';

/// The calendar's view model, derived from the dashboard payload.
///
/// Watching [dashboardProvider] rather than fetching again means the calendar
/// and the dashboard can never disagree, and an invalidation from either screen
/// refreshes both. Only the *view* state (focused month, selected day) lives
/// here; the events come from the shared fetch.
///
/// Async so the screen can render skeletons and errors the same way the
/// dashboard does.
final Provider<AsyncValue<CalendarData>> calendarProvider = Provider<AsyncValue<CalendarData>>((Ref ref) {
  final CalendarViewState view = ref.watch(calendarViewProvider);
  final AsyncValue<DashboardData> events = ref.watch(dashboardProvider);

  return events.whenData(
    (DashboardData data) => CalendarData.fromDashboard(
      data,
      focusedMonth: view.focusedMonth,
      selectedDate: view.selectedDate,
    ),
  );
});

/// Which month the grid is showing and which day is selected.
///
/// Separate from [calendarProvider] so paging through months does not re-run the
/// dashboard fetch, and so a fetch failure does not lose the user's place.
class CalendarViewController extends Notifier<CalendarViewState> {
  @override
  CalendarViewState build() {
    final DateTime now = DateTime.now();
    return CalendarViewState(
      focusedMonth: DateTime(now.year, now.month),
      selectedDate: CalendarData.dayOf(now),
    );
  }

  void focusMonth(DateTime month) {
    state = state.copyWith(focusedMonth: DateTime(month.year, month.month));
  }

  void selectDate(DateTime day) {
    state = state.copyWith(selectedDate: CalendarData.dayOf(day));
  }
}

class CalendarViewState {
  const CalendarViewState({required this.focusedMonth, required this.selectedDate});

  final DateTime focusedMonth;
  final DateTime selectedDate;

  CalendarViewState copyWith({DateTime? focusedMonth, DateTime? selectedDate}) {
    return CalendarViewState(
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

/// Public handle for the month/day selection, used by the grid and navigator.
final calendarViewProvider =
    NotifierProvider<CalendarViewController, CalendarViewState>(CalendarViewController.new);
