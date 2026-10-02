import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsi_flutter/core/network/api_client.dart';
import 'package:lsi_flutter/core/network/fake/fake_api_adapter.dart';
import 'package:lsi_flutter/core/storage/token_storage.dart';
import 'package:lsi_flutter/core/theme/app_theme.dart';
import 'package:lsi_flutter/core/utils/json_parsing.dart';
import 'package:lsi_flutter/features/activity/presentation/activity_screen.dart';
import 'package:lsi_flutter/features/assignments/data/assignment_repository.dart';
import 'package:lsi_flutter/features/assignments/domain/assignment_models.dart';
import 'package:lsi_flutter/features/assignments/presentation/assignments_screen.dart';
import 'package:lsi_flutter/features/assignments/state/assignment_providers.dart';
import 'package:lsi_flutter/features/auth/domain/app_user.dart';
import 'package:lsi_flutter/features/auth/state/auth_providers.dart';
import 'package:lsi_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:lsi_flutter/features/dashboard/domain/dashboard_data.dart';
import 'package:lsi_flutter/features/exams/state/exam_providers.dart';
import 'package:lsi_flutter/features/grades/data/grade_repository.dart';
import 'package:lsi_flutter/features/grades/domain/grade_models.dart';
import 'package:lsi_flutter/features/grades/presentation/grades_screen.dart';
import 'package:lsi_flutter/features/grades/state/grade_providers.dart';
import 'package:lsi_flutter/features/leaderboard/data/leaderboard_repository.dart';
import 'package:lsi_flutter/features/leaderboard/domain/leaderboard_models.dart';
import 'package:lsi_flutter/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:lsi_flutter/features/leaderboard/state/leaderboard_providers.dart';
import 'package:lsi_flutter/features/more/presentation/more_screen.dart';
import 'package:lsi_flutter/features/profile/data/profile_repository.dart';
import 'package:lsi_flutter/features/profile/domain/xp_history.dart';
import 'package:lsi_flutter/features/profile/presentation/profile_screen.dart';
import 'package:lsi_flutter/features/profile/state/profile_providers.dart';

/// Keeps the token in memory; the real one needs a platform keystore.
class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// The fake backend behind the real client, so repositories and parsing are on
/// the path exactly as they are in the app.
ApiClient _client() {
  final ApiClient client = ApiClient(tokenStorage: _MemoryTokenStorage(), dio: Dio());
  client.raw.httpClientAdapter = FakeApiAdapter();
  return client;
}

class _FakeSession extends SessionController {
  @override
  Future<AppUser?> build() async => const AppUser(
    id: 1,
    publicId: 'LSI-2026-0001',
    name: 'Juan Dela Cruz',
    email: 'student@lsi.test',
    level: 12,
    currentStreak: 7,
    exp: 2480,
  );
}

/// The exam list endpoint is shared with the Exams tab; the Activity page should
/// still render when it has nothing.
class _EmptyExamList extends ExamListController {
  @override
  Future<ExamListState> build() async => const ExamListState();
}

void main() {
  group('payloads', () {
    test('grades keep ungraded periods and flatten senior-high quarters', () async {
      final GradesData data = await GradeRepository(_client()).fetch();

      expect(data.subjects, hasLength(3));

      final SubjectGrade maths = data.subjects.first;
      expect(maths.subject, 'General Mathematics');
      // Four periods are visible even though only two are marked — dropping the
      // ungraded ones would make this subject look finished.
      expect(maths.periods, hasLength(4));
      expect(maths.gradedCount, 2);
      expect(maths.isComplete, isFalse);
      expect(maths.standing, 89.75);

      final SubjectGrade pe = data.subjects[1];
      expect(pe.isComplete, isTrue);
      expect(pe.standing, 95.5);

      final SubjectGrade english = data.subjects[2];
      expect(english.schoolLevelLabel, 'Senior High');
      // Senior high has no periodGrades; the quarters come out of the semesters.
      expect(english.periods, hasLength(4));
      expect(english.periods.first.group, 'First Semester');
      expect(english.gradedCount, 2);
      expect(english.standing, 93);

      expect(data.overallAverage, isNotNull);
      expect(data.completedSubjects, 1);
    });

    test('assignments split into outstanding and handed in', () async {
      final AssignmentsData data = await AssignmentRepository(_client()).fetch();

      expect(data.assignments, hasLength(5));
      expect(data.overdueCount, 1);
      expect(data.outstanding, hasLength(4));
      expect(data.completed, hasLength(1));

      // Outstanding work reads soonest-deadline-first.
      final List<DateTime> due = data.outstanding
          .map((AssignmentItem a) => a.dueAt!)
          .toList(growable: false);
      expect(due, orderedEquals(<DateTime>[...due]..sort()));

      final AssignmentItem graded = data.completed.single;
      expect(graded.isGraded, isTrue);
      expect(graded.grade, '18/20');
      expect(graded.hasUnseenFeedback, isTrue);

      final AssignmentItem groupWork = data.assignments.firstWhere((AssignmentItem a) => a.isGroupWork);
      expect(groupWork.groupMax, 4);
      expect(groupWork.memberCount, 2);
    });

    test('leaderboard keeps the hidden board and its flag', () async {
      final LeaderboardData data = await LeaderboardRepository(_client()).fetch();

      expect(data.seasonName, 'First Semester');
      expect(data.boards, hasLength(2));
      expect(data.boards.first.leaderboardEnabled, isTrue);
      expect(data.boards.first.users, hasLength(8));
      expect(data.boards.first.users.where((LeaderboardUser u) => u.isCurrentUser), hasLength(1));
      expect(data.boards[1].leaderboardEnabled, isFalse);
    });

    test('xp history parses amounts, deductions, and its timestamps', () async {
      final XpHistory data = await ProfileRepository(_client()).fetchXpHistory('LSI-2026-0001');

      expect(data.entries, isNotEmpty);
      expect(data.deductionCount, 2);
      expect(data.netXp, greaterThan(0));

      final XpEntry first = data.entries.first;
      expect(first.amountXp, 50);
      expect(first.isCredit, isTrue);
      expect(first.amountLabel, '+50 XP');
      // Without this the ledger cannot be grouped or sorted by day.
      expect(first.createdAt, isNotNull);

      final XpEntry deduction = data.entries.firstWhere((XpEntry e) => !e.isCredit);
      expect(deduction.isCredit, isFalse);
      expect(deduction.amountLabel.startsWith('−'), isTrue);
    });

    test('ledger reasons map onto the categories the level sheet groups by', () async {
      final XpHistory data = await ProfileRepository(_client()).fetchXpHistory('LSI-2026-0001');

      // Every reason the fixture carries is one the server actually writes, so
      // the grouping under test is the grouping production will do.
      final Set<String> reasons = data.entries.map((XpEntry e) => e.reason).toSet();
      expect(
        reasons.difference(<String>{
          'Daily Claim',
          'Bonus Claim',
          'Assignment Graded',
          'Exam Submission',
          'Exam Completion XP',
          'On-time Exam XP',
          'Exam Accuracy XP',
          'Season Reward',
          'Admin Adjustment',
        }),
        isEmpty,
        reason: 'fixture used a reason the server never writes: $reasons',
      );

      expect(data.entries.firstWhere((XpEntry e) => e.reason == 'Daily Claim').category, XpCategory.daily);
      expect(data.entries.firstWhere((XpEntry e) => e.reason == 'Bonus Claim').category, XpCategory.bonus);
      expect(
        data.entries.firstWhere((XpEntry e) => e.reason == 'Assignment Graded').category,
        XpCategory.assignment,
      );
      expect(
        data.entries.firstWhere((XpEntry e) => e.reason == 'Exam Completion XP').category,
        XpCategory.exam,
      );
      expect(data.entries.firstWhere((XpEntry e) => e.reason == 'Season Reward').category, XpCategory.season);

      // A reason added server-side later must not make an entry disappear.
      expect(XpCategory.fromReason('Something New'), XpCategory.other);

      // The breakdown sums back to the net total.
      final double summed = data.byCategory.values
          .fold<double>(0, (double sum, double value) => sum + value);
      expect(summed, closeTo(data.netXp, 0.001));
    });

    test('level arithmetic follows the server rule', () async {
      final DashboardData data = await DashboardRepository(_client()).fetch();
      final UserStats stats = data.userStats;

      // `levelFromExp = floor(exp / 100) + 1`, and `currentXP = exp % 100`.
      expect(stats.level, (stats.totalXP ~/ 100) + 1);
      expect(stats.currentXP, stats.totalXP % 100);
      expect(stats.xpToNextLevel, closeTo(stats.maxXPForLevel - stats.currentXP, 0.001));
      expect(stats.xpToNextLevel, greaterThanOrEqualTo(0));
      expect(stats.xpAtNextLevel, closeTo(stats.totalXP + stats.xpToNextLevel, 0.001));
      expect(stats.nextLevel, stats.level + 1);
    });

    test('the claim amount follows the streak formula', () async {
      final DashboardData data = await DashboardRepository(_client()).fetch();

      // ClaimXpService: base + min(4, floor(streak / 5)).
      final int expected = 10 + (data.userStats.streak ~/ 5).clamp(0, 4);
      expect(data.claimXp.amount, expected);
    });

    group('parseFlexibleDate', () {
      test('reads the XP ledger format', () {
        expect(parseFlexibleDate('Sep 01, 2026 08:30'), DateTime(2026, 9, 1, 8, 30));
      });

      test('reads a month-name date with no clock', () {
        expect(parseFlexibleDate('Sep 01, 2026'), DateTime(2026, 9, 1));
      });

      test('still reads ISO, and gives up on nonsense', () {
        expect(parseFlexibleDate('2026-09-01T08:30:00Z'), isNotNull);
        expect(parseFlexibleDate('not a date'), isNull);
        expect(parseFlexibleDate(''), isNull);
      });
    });
  });

  group('rendering', () {
    late GradesData grades;
    late AssignmentsData assignments;
    late LeaderboardData boards;
    late XpHistory ledger;

    setUpAll(() async {
      final ApiClient client = _client();
      grades = await GradeRepository(client).fetch();
      assignments = await AssignmentRepository(client).fetch();
      boards = await LeaderboardRepository(client).fetch();
      ledger = await ProfileRepository(client).fetchXpHistory('LSI-2026-0001');
    });

    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_FakeSession.new),
            examListProvider.overrideWith(_EmptyExamList.new),
            gradesProvider.overrideWith((Ref ref) async => grades),
            assignmentsProvider.overrideWith((Ref ref) async => assignments),
            leaderboardProvider.overrideWith((Ref ref) async => boards),
            xpHistoryProvider.overrideWith((Ref ref) async => ledger),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: page),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // A layout fault is what blanked the dashboard, so every new page is
      // checked for one rather than only for the text it should show.
      expect(tester.takeException(), isNull);
    }

    testWidgets('grades page shows a subject and its provisional standing', (WidgetTester tester) async {
      await pumpPage(tester, const GradesScreen());

      expect(find.text('Grades'), findsOneWidget);
      expect(find.text('Overall average'), findsOneWidget);
      // Section headers render uppercase.
      expect(find.text('GENERAL MATHEMATICS'), findsOneWidget);
      expect(find.text('Provisional'), findsWidgets);
    });

    testWidgets('assignments page flags what is overdue', (WidgetTester tester) async {
      await pumpPage(tester, const AssignmentsScreen());

      expect(find.text('Assignments'), findsOneWidget);
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.text('1 assignment is past the deadline.'), findsOneWidget);
    });

    testWidgets('leaderboard page renders a podium', (WidgetTester tester) async {
      await pumpPage(tester, const LeaderboardScreen());

      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Season standings'), findsOneWidget);
      expect(find.text('BSED MATHEMATICS - A'), findsOneWidget);
    });

    testWidgets('profile page keeps its header while the ledger loads', (WidgetTester tester) async {
      await pumpPage(tester, const ProfileScreen());

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('XP HISTORY'), findsOneWidget);
      expect(find.text('+50 XP'), findsWidgets);
    });

    testWidgets('activity page renders with no exams at all', (WidgetTester tester) async {
      await pumpPage(tester, const ActivityScreen());

      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('RECENT XP'), findsOneWidget);
    });

    testWidgets('more menu lists destinations and marks the unbuilt ones', (WidgetTester tester) async {
      await pumpPage(tester, const MoreScreen());

      expect(find.text('More'), findsOneWidget);
      expect(find.text('LEARNING'), findsOneWidget);
      expect(find.text('APP'), findsOneWidget);
      expect(find.text('NOT ON MOBILE YET'), findsOneWidget);
      expect(find.text('Grades'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      // Chats and Settings are built now, so only the three web-only
      // destinations still carry a marker.
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Games'), findsOneWidget);
      expect(find.text('Soon'), findsNWidgets(3));
    });
  });
}
