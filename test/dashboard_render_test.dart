import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsi_flutter/core/theme/app_theme.dart';
import 'package:lsi_flutter/features/auth/domain/app_user.dart';
import 'package:lsi_flutter/features/auth/state/auth_providers.dart';
import 'package:lsi_flutter/features/dashboard/domain/dashboard_data.dart';
import 'package:lsi_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lsi_flutter/features/dashboard/state/dashboard_providers.dart';

/// A session controller that never touches the network.
class _FakeSession extends SessionController {
  @override
  Future<AppUser?> build() async => const AppUser(
    id: 1,
    publicId: 'LSI-2026-0001',
    name: 'Juan Dela Cruz',
    email: 'student@lsi.test',
  );
}

DashboardData _payload() {
  final DateTime now = DateTime(2026, 10, 2, 9);

  return DashboardData(
    userStats: const UserStats(
      totalXP: 2480,
      level: 12,
      currentXP: 80,
      maxXPForLevel: 100,
      points: 340,
      streak: 7,
      longestStreak: 21,
    ),
    loginDates: <String>{'2026-10-01', '2026-10-02'},
    announcements: <Announcement>[
      const Announcement(
        id: 1,
        title: 'Midterm exam schedule is up',
        description: 'Check the Exams tab for your assigned set and part order.',
        link: null,
        sectionName: 'BSED Mathematics',
        createdAtLabel: 'Sep 01, 2026',
      ),
    ],
    assignments: <AssignmentSummary>[
      AssignmentSummary(
        id: 11,
        title: 'Problem Set 4: Integrals',
        description: 'Show all work.',
        dueLabel: 'in 3 days',
        dueAt: now.add(const Duration(days: 3)),
        isOverdue: false,
        submitted: false,
        status: 'Pending',
        grade: null,
      ),
    ],
    upcomingExams: <UpcomingExam>[
      UpcomingExam(
        id: 101,
        title: 'Calculus Midterm',
        description: 'Covers limits, derivatives and integrals.',
        examDateLabel: null,
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(days: 3)),
        durationMinutes: 90,
        status: 'published',
        partsCount: 2,
        submittedParts: 0,
        isCompleted: false,
        isOpenNow: true,
        isUpcoming: false,
        hasEnded: false,
        setTitle: 'Set B',
      ),
    ],
    sectionLeaderboards: const <SectionLeaderboard>[
      SectionLeaderboard(
        sectionId: 1,
        sectionName: 'BSED Mathematics - A',
        leaderboardEnabled: true,
        userRank: 4,
        totalPlayers: 62,
        users: <LeaderboardUser>[
          LeaderboardUser(
            id: 1,
            publicId: 'LSI-2026-0001',
            name: 'Ana Reyes',
            xp: 5200,
            level: 14,
            xpProgress: 0,
            streak: 9,
            trend: 'up',
            isCurrentUser: false,
            blurred: false,
          ),
        ],
      ),
    ],
    claimXp: const ClaimStatus(canClaim: true, amount: 10),
    bonusXp: const ClaimStatus(canClaim: true, amount: 50),
    availableSeasons: const <SeasonOption>[SeasonOption(id: 1, name: 'First Semester')],
    activeSeasonName: 'First Semester',
  );
}

void main() {
  testWidgets('dashboard renders every section from its payload', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_FakeSession.new),
          dashboardProvider.overrideWith((Ref ref) async => _payload()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const DashboardScreen()),
      ),
    );

    // Resolve the overridden future, then let the tree settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // A layout fault here used to blank the entire body, so the exception check
    // matters as much as the content checks below.
    expect(tester.takeException(), isNull);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Season XP'), findsOneWidget);
    expect(find.text('Day streak'), findsOneWidget);

    // Both rewards are claimable in this payload. Rendering two of them is the
    // exact case that previously forced an infinite width inside a Row and took
    // the whole screen down with it, so it is asserted explicitly.
    expect(find.text('Daily streak reward'), findsOneWidget);
    expect(find.text('Bonus XP'), findsOneWidget);
    expect(find.text('Claim'), findsNWidgets(2));

    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('Calculus Midterm'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });
}
