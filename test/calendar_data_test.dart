import 'package:flutter_test/flutter_test.dart';
import 'package:lsi_flutter/features/calendar/domain/calendar_data.dart';
import 'package:lsi_flutter/features/dashboard/domain/dashboard_data.dart';

DashboardData _dashboard({
  List<UpcomingExam> exams = const <UpcomingExam>[],
  List<AssignmentSummary> assignments = const <AssignmentSummary>[],
  Set<String> loginDates = const <String>{},
}) {
  return DashboardData(
    userStats: const UserStats(
      totalXP: 0,
      level: 1,
      currentXP: 0,
      maxXPForLevel: 100,
      points: 0,
      streak: 0,
      longestStreak: 0,
    ),
    loginDates: loginDates,
    announcements: const <Announcement>[],
    assignments: assignments,
    upcomingExams: exams,
    sectionLeaderboards: const <SectionLeaderboard>[],
    claimXp: const ClaimStatus(canClaim: false, amount: 0),
    bonusXp: const ClaimStatus(canClaim: false, amount: 0),
    availableSeasons: const <SeasonOption>[],
    activeSeasonName: null,
  );
}

UpcomingExam _exam({
  int id = 1,
  DateTime? startsAt,
  DateTime? endsAt,
  bool isOpenNow = false,
  bool isUpcoming = false,
  bool hasEnded = false,
}) {
  return UpcomingExam(
    id: id,
    title: 'Exam $id',
    description: null,
    examDateLabel: null,
    startsAt: startsAt,
    endsAt: endsAt,
    durationMinutes: 60,
    status: 'published',
    partsCount: 1,
    submittedParts: 0,
    isCompleted: false,
    isOpenNow: isOpenNow,
    isUpcoming: isUpcoming,
    hasEnded: hasEnded,
    setTitle: 'Set A',
  );
}

AssignmentSummary _assignment({
  int id = 1,
  DateTime? dueAt,
  bool isOverdue = false,
  bool submitted = false,
  String? grade,
}) {
  return AssignmentSummary(
    id: id,
    title: 'Assignment $id',
    description: null,
    dueLabel: 'soon',
    dueAt: dueAt,
    isOverdue: isOverdue,
    submitted: submitted,
    status: 'Pending',
    grade: grade,
  );
}

void main() {
  final DateTime now = DateTime(2026, 9, 15, 10, 30);

  group('monthGrid', () {
    test('always returns whole Monday-start weeks', () {
      final List<DateTime> grid = CalendarData.monthGrid(DateTime(2026, 9, 1));

      expect(grid.length, 42);
      expect(grid.first.weekday, DateTime.monday);
      expect(grid.first, DateTime(2026, 8, 31));
      expect(grid.last, DateTime(2026, 10, 11));
    });

    test('starts on the 1st for a month that begins on Monday', () {
      // June 2026 begins on a Monday, so no spillover at the start.
      final List<DateTime> grid = CalendarData.monthGrid(DateTime(2026, 6, 1));

      expect(grid.first, DateTime(2026, 6, 1));
    });
  });

  group('fromDashboard', () {
    test('maps exam windows to the first day they can be taken', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(
          exams: <UpcomingExam>[
            _exam(
              id: 7,
              startsAt: DateTime(2026, 9, 20, 8),
              endsAt: DateTime(2026, 9, 22, 20),
              isOpenNow: true,
            ),
          ],
        ),
        now: now,
      );

      final CalendarEvent event = calendar.events.single;
      expect(event.kind, CalendarEventKind.examOpen);
      expect(event.examId, 7);
      // The start datetime, normalised to midnight — not the exam's end date.
      expect(event.date, DateTime(2026, 9, 20));
      expect(event.time, contains('8'));
    });

    test('classifies an ended exam even when isOpenNow is false', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(
          exams: <UpcomingExam>[
            _exam(
              id: 8,
              startsAt: DateTime(2026, 9, 1),
              endsAt: DateTime(2026, 9, 2),
              hasEnded: true,
            ),
          ],
        ),
        now: now,
      );

      expect(calendar.events.single.kind, CalendarEventKind.examEnded);
    });

    test('marks an overdue unsubmitted assignment, but not a submitted one', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(
          assignments: <AssignmentSummary>[
            _assignment(id: 1, dueAt: DateTime(2026, 9, 10), isOverdue: true, submitted: false),
            _assignment(id: 2, dueAt: DateTime(2026, 9, 10), isOverdue: true, submitted: true),
          ],
        ),
        now: now,
      );

      final List<CalendarEvent> events =
          calendar.events.where((CalendarEvent e) => e.kind.isAssignment).toList();

      expect(events.firstWhere((CalendarEvent e) => e.id == 'assignment-1').isOverdue, isTrue);
      // Submitted work is not "overdue" even though the deadline passed.
      expect(events.firstWhere((CalendarEvent e) => e.id == 'assignment-2').isOverdue, isFalse);
    });

    test('skips assignments with no due date instead of crashing', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(assignments: <AssignmentSummary>[_assignment(dueAt: null)]),
        now: now,
      );

      expect(calendar.events.where((CalendarEvent e) => e.kind.isAssignment), isEmpty);
    });

    test('turns login dates into events and records them as activity', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(loginDates: <String>{'2026-09-15', '2026-09-14'}),
        now: now,
      );

      expect(calendar.events.where((CalendarEvent e) => e.kind == CalendarEventKind.login), hasLength(2));
      expect(calendar.daysWithActivity, contains('2026-09-15'));
    });

    test('ignores malformed login date keys', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(loginDates: <String>{'not-a-date', '2026-13-99', '2026-09-14'}),
        now: now,
      );

      expect(calendar.events.where((CalendarEvent e) => e.kind == CalendarEventKind.login), hasLength(1));
    });

    test('orders actionable kinds ahead of login history', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(
          exams: <UpcomingExam>[_exam(id: 1, startsAt: DateTime(2026, 9, 15, 9))],
          assignments: <AssignmentSummary>[_assignment(id: 1, dueAt: DateTime(2026, 9, 15, 23))],
          loginDates: <String>{'2026-09-15'},
        ),
        now: now,
      );

      expect(calendar.events.map((CalendarEvent e) => e.kind).toSet(), hasLength(3));
      expect(calendar.events.last.kind, CalendarEventKind.login);
    });
  });

  group('queries', () {
    CalendarData build() => CalendarData.fromDashboard(
          _dashboard(
            exams: <UpcomingExam>[
              _exam(id: 1, startsAt: DateTime(2026, 9, 20, 8), isOpenNow: true),
              _exam(id: 2, startsAt: DateTime(2026, 10, 2, 8), isUpcoming: true),
            ],
            assignments: <AssignmentSummary>[
              _assignment(id: 1, dueAt: DateTime(2026, 9, 20, 23)),
            ],
          ),
          now: now,
        );

    test('eventsOn returns everything on a day', () {
      final CalendarData calendar = build();
      final List<CalendarEvent> events = calendar.eventsOn(DateTime(2026, 9, 20));

      expect(events, hasLength(2));
      expect(events.every((CalendarEvent e) => e.dateKey == '2026-09-20'), isTrue);
    });

    test('eventsOn ignores the time component', () {
      final CalendarData calendar = build();

      expect(calendar.eventsOn(DateTime(2026, 9, 20, 23, 59)), hasLength(2));
      expect(calendar.hasEventOn(DateTime(2026, 9, 21)), isFalse);
    });

    test('eventCountIn counts only the named month', () {
      final CalendarData calendar = build();

      expect(calendar.eventCountIn(DateTime(2026, 9)), 2);
      expect(calendar.eventCountIn(DateTime(2026, 10)), 1);
    });

    test('agendaFrom omits past days and groups by day', () {
      // `now` is Sep 15; the first event is Sep 20, so the first group is a
      // dated label, not "Today".
      final CalendarData calendar = build();
      final List<CalendarDayGroup> groups = calendar.agendaFrom(now);

      expect(groups, hasLength(2));
      expect(groups.first.events, hasLength(2));
      expect(groups.first.label, 'Sunday, Sep 20');
    });

    test('agendaFrom labels the current day "Today"', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(
          assignments: <AssignmentSummary>[_assignment(id: 1, dueAt: DateTime(2026, 9, 15, 23))],
        ),
        now: now,
      );

      expect(calendar.agendaFrom(now).single.label, 'Today');
    });

    test('agendaFrom respects its limit', () {
      final CalendarData calendar = CalendarData.fromDashboard(
        _dashboard(
          exams: <UpcomingExam>[
            for (int i = 1; i <= 6; i++)
              _exam(id: i, startsAt: DateTime(2026, 9, 20 + i, 8), isUpcoming: true),
          ],
        ),
        now: now,
      );

      expect(calendar.agendaFrom(now, limit: 3), hasLength(3));
    });
  });

  group('dateKeyOf', () {
    test('zero-pads month and day so keys sort lexicographically', () {
      expect(CalendarData.dateKeyOf(DateTime(2026, 1, 5)), '2026-01-05');
      expect(CalendarData.dateKeyOf(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
