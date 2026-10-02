import 'package:intl/intl.dart';

import '../../dashboard/domain/dashboard_data.dart';

/// What a calendar entry represents.
enum CalendarEventKind {
  examOpen('Exam', 'Open now'),
  examUpcoming('Exam', 'Upcoming'),
  examEnded('Exam', 'Ended'),
  assignmentDue('Assignment', 'Due'),
  assignmentOverdue('Assignment', 'Overdue'),
  login('Activity', 'Signed in');

  const CalendarEventKind(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  bool get isExam => this == examOpen || this == examUpcoming || this == examEnded;

  bool get isAssignment => this == assignmentDue || this == assignmentOverdue;
}

/// One dated entry on the calendar.
///
/// Every field is derived from data the client already fetches, so the calendar
/// needs no new endpoint. See [CalendarData.fromDashboard] for the mapping.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    this.subtitle,
    this.time,
    this.examId,
    this.sectionName,
  });

  final String id;
  final CalendarEventKind kind;
  final String title;

  /// Local midnight on the day this event falls on. Used as the map key for the
  /// month grid, so it is normalised rather than the raw timestamp.
  final DateTime date;

  final String? subtitle;

  /// Start time when the source data carries one, formatted for display.
  final String? time;
  final int? examId;
  final String? sectionName;

  /// `yyyy-MM-dd`, matching the key format the dashboard heatmap uses.
  String get dateKey => CalendarData.dateKeyOf(date);

  bool get isOverdue => kind == CalendarEventKind.assignmentOverdue;
}

/// A contiguous run of days sharing a label, as shown under a month header.
class CalendarDayGroup {
  const CalendarDayGroup({
    required this.label,
    required this.events,
    required this.isOverdue,
  });

  final String label;
  final List<CalendarEvent> events;

  /// True when the group's only events are overdue, so the header can be tinted.
  final bool isOverdue;

  bool get isEmpty => events.isEmpty;
}

/// The calendar's derived view model.
class CalendarData {
  const CalendarData({
    required this.events,
    required this.focusedMonth,
    required this.selectedDate,
    required this.daysWithActivity,
  });

  final List<CalendarEvent> events;
  final DateTime focusedMonth;
  final DateTime selectedDate;

  /// `yyyy-MM-dd` keys from the dashboard's 90-day login set, used to mark days
  /// the student was active even when nothing is scheduled.
  final Set<String> daysWithActivity;

  bool get isEmpty => events.isEmpty;

  static final DateFormat _monthLabel = DateFormat('MMMM yyyy');
  static final DateFormat _dayLabel = DateFormat('EEEE, MMM d');
  static final DateFormat _todayLabel = DateFormat('EEEE, MMM d');
  static final DateFormat _timeLabel = DateFormat.jm();

  /// Local midnight for [date], stripping any time component.
  static DateTime dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

  static String dateKeyOf(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Every day of [month], padded to whole Monday-start weeks so the grid is
  /// always a multiple of seven cells.
  static List<DateTime> monthGrid(DateTime month) {
    final DateTime first = DateTime(month.year, month.month, 1);
    // DateTime.monday == 1, so this is the offset back to the grid's first cell.
    final DateTime start = first.subtract(Duration(days: first.weekday - DateTime.monday));

    return List<DateTime>.generate(42, (int i) => start.add(Duration(days: i)));
  }

  /// Builds the calendar from the dashboard payload.
  ///
  /// There is no calendar endpoint, so this projects three sources onto one
  /// timeline: exam windows (from `upcomingExams`), assignment deadlines (from
  /// `assignments`, which the UI otherwise only shows as a preformatted
  /// string), and login days (from the same 90-day set the heatmap uses).
  factory CalendarData.fromDashboard(
    DashboardData dashboard, {
    DateTime? now,
    DateTime? focusedMonth,
    DateTime? selectedDate,
  }) {
    final DateTime today = dayOf(now ?? DateTime.now());
    final List<CalendarEvent> events = <CalendarEvent>[];

    for (final UpcomingExam exam in dashboard.upcomingExams) {
      // A scheduled exam spans its whole open window, so mark the first day it
      // can be taken rather than only exam_date — that is the day a student
      // needs to act on.
      final DateTime? anchor = exam.startsAt ?? exam.endsAt;
      if (anchor == null) continue;

      // A published exam whose window has passed is still worth showing, so
      // the calendar does not lose the "you sat this" record.
      final bool isEnded = exam.hasEnded || (exam.endsAt != null && exam.endsAt!.isBefore(today));
      final bool isUpcoming = !exam.isOpenNow && !isEnded;

      events.add(
        CalendarEvent(
          id: 'exam-${exam.id}',
          kind: isEnded
              ? CalendarEventKind.examEnded
              : (isUpcoming ? CalendarEventKind.examUpcoming : CalendarEventKind.examOpen),
          title: exam.title,
          date: dayOf(anchor),
          time: exam.startsAt != null ? _timeLabel.format(exam.startsAt!.toLocal()) : null,
          examId: exam.id,
          sectionName: exam.setTitle,
        ),
      );
    }

    for (final AssignmentSummary assignment in dashboard.assignments) {
      // `dueAtIso` is timezone-naive by design, so it is read as local time.
      final DateTime? due = assignment.dueAt;
      if (due == null) continue;

      final DateTime day = dayOf(due);
      final bool overdue = assignment.isOverdue && !assignment.submitted;

      events.add(
        CalendarEvent(
          id: 'assignment-${assignment.id}',
          kind: overdue
              ? CalendarEventKind.assignmentOverdue
              : CalendarEventKind.assignmentDue,
          title: assignment.title,
          date: day,
          subtitle: assignment.grade,
          sectionName: null,
        ),
      );
    }

    for (final String key in dashboard.loginDates) {
      final DateTime? date = _parseDateKey(key);
      if (date == null) continue;

      events.add(
        CalendarEvent(
          id: 'login-$key',
          kind: CalendarEventKind.login,
          title: 'Signed in',
          date: date,
        ),
      );
    }

    events.sort((CalendarEvent a, CalendarEvent b) {
      // Exams first, then assignments, then logins: on a given day the things
      // that need action outrank the ones that are just history.
      final int byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.date.compareTo(b.date);
    });

    return CalendarData(
      events: events,
      focusedMonth: focusedMonth ?? DateTime(today.year, today.month),
      selectedDate: selectedDate ?? today,
      daysWithActivity: dashboard.loginDates,
    );
  }

  static DateTime? _parseDateKey(String key) {
    final List<String> parts = key.split('-');
    if (parts.length != 3) return null;

    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final DateTime date = DateTime(year, month, day);

    // DateTime rolls over rather than rejecting an out-of-range component, so
    // `2026-13-99` becomes a real date in the following year. Comparing the
    // components back catches that; without it a malformed key would silently
    // invent an event on a day the student was never active.
    if (date.year != year || date.month != month || date.day != day) return null;

    return date;
  }

  /// Events falling on [day].
  List<CalendarEvent> eventsOn(DateTime day) {
    final String key = dateKeyOf(day);
    return events.where((CalendarEvent e) => e.dateKey == key).toList(growable: false);
  }

  bool hasEventOn(DateTime day) => eventsOn(day).isNotEmpty;

  /// Count of events in the focused month, used to decide whether a month
  /// deserves a dot in the year strip.
  int eventCountIn(DateTime month) {
    return events
        .where((CalendarEvent e) => e.date.year == month.year && e.date.month == month.month)
        .length;
  }

  /// Whether [month] contains any day at all, including the 42-cell grid's
  /// spillover days.
  bool hasAnyEventIn(DateTime month) {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 0);
    return events.any((CalendarEvent e) => !e.date.isBefore(start) && !e.date.isAfter(end));
  }

  /// Events grouped by day, ordered soonest-last, for the agenda list under the
  /// month grid. Groups past [from] only.
  List<CalendarDayGroup> agendaFrom(DateTime from, {int limit = 20}) {
    final Map<String, List<CalendarEvent>> byDay = <String, List<CalendarEvent>>{};

    for (final CalendarEvent event in events) {
      if (event.date.isBefore(dayOf(from))) continue;
      byDay.putIfAbsent(event.dateKey, () => <CalendarEvent>[]).add(event);
    }

    final List<String> keys = byDay.keys.toList()..sort();
    return keys.take(limit).map((String key) {
      final List<CalendarEvent> dayEvents = byDay[key]!;
      final DateTime date = dayEvents.first.date;
      final bool isToday = dateKeyOf(dayOf(from)) == key;

      return CalendarDayGroup(
        label: isToday ? 'Today' : _dayLabel.format(date),
        events: dayEvents,
        isOverdue: dayEvents.every((CalendarEvent e) => e.isOverdue),
      );
    }).toList(growable: false);
  }

  String get focusedMonthLabel => _monthLabel.format(focusedMonth);

  /// "Today" or "Tuesday, Oct 14" for the selected-day header.
  String labelFor(DateTime day) {
    final DateTime date = dayOf(day);
    if (dateKeyOf(date) == dateKeyOf(dayOf(DateTime.now()))) return 'Today';
    return _todayLabel.format(date);
  }

  CalendarData copyWith({DateTime? focusedMonth, DateTime? selectedDate}) {
    return CalendarData(
      events: events,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      daysWithActivity: daysWithActivity,
    );
  }
}
