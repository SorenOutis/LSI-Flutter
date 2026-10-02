import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsi_flutter/core/network/api_client.dart';
import 'package:lsi_flutter/core/network/fake/fake_api_adapter.dart';
import 'package:lsi_flutter/core/storage/token_storage.dart';
import 'package:lsi_flutter/core/theme/app_theme.dart';
import 'package:lsi_flutter/shared/widgets/app_sheet.dart';
import 'package:lsi_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:lsi_flutter/features/dashboard/domain/dashboard_data.dart';
import 'package:lsi_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lsi_flutter/features/dashboard/presentation/sheets/claim_sheet.dart';
import 'package:lsi_flutter/features/dashboard/presentation/sheets/level_sheet.dart';
import 'package:lsi_flutter/features/dashboard/presentation/sheets/points_sheet.dart';
import 'package:lsi_flutter/features/dashboard/presentation/sheets/streak_sheet.dart';
import 'package:lsi_flutter/features/dashboard/state/dashboard_providers.dart';
import 'package:lsi_flutter/features/exams/state/exam_providers.dart';
import 'package:lsi_flutter/features/profile/data/profile_repository.dart';
import 'package:lsi_flutter/features/profile/domain/xp_history.dart';
import 'package:lsi_flutter/features/profile/state/profile_providers.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

ApiClient _client() {
  final ApiClient client = ApiClient(tokenStorage: _MemoryTokenStorage(), dio: Dio());
  client.raw.httpClientAdapter = FakeApiAdapter();
  return client;
}

class _EmptyExamList extends ExamListController {
  @override
  Future<ExamListState> build() async => const ExamListState();
}

void main() {
  late DashboardData data;
  late XpHistory ledger;

  setUpAll(() async {
    final ApiClient client = _client();
    data = await DashboardRepository(client).fetch();
    ledger = await ProfileRepository(client).fetchXpHistory('LSI-2026-0001');
  });

  Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          xpHistoryProvider.overrideWith((Ref ref) async => ledger),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                // The sheet content, inside the same constraints a real sheet
                // gets: a bounded height and the screen's insets.
                child: SizedBox(height: 700, child: sheet),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  }

  /// Brings [finder] into view inside the sheet's scrolling body.
///
/// A sheet is a scrolling list, so anything below the fold is not built until it
  /// is reached — asserting on it without scrolling would pass on content the
  /// student cannot see either.
  Future<void> revealInSheet(WidgetTester tester, Finder finder) async {
    // Scoped to the sheet: the route underneath has its own list, and dragging
    // that one would scroll the dashboard behind the modal.
    final Finder sheetList = find.descendant(
      of: find.byType(AppSheet),
      matching: find.byType(ListView),
    );

    for (int attempt = 0; attempt < 10 && finder.evaluate().isEmpty; attempt++) {
      await tester.drag(sheetList.first, const Offset(0, -180));
      await tester.pumpAndSettle();
    }

    expect(finder, findsWidgets);
    expect(tester.takeException(), isNull);
  }

  testWidgets('the level sheet states the real level arithmetic', (WidgetTester tester) async {
    await pumpSheet(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showLevelSheet(context, data.userStats),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Level ${data.userStats.level}'), findsWidgets);
    expect(find.textContaining('XP to Level ${data.userStats.nextLevel}'), findsOneWidget);
    expect(find.textContaining('A level is 100 XP'), findsOneWidget);

    // Badges: progress only, and the sheet admits the API has no list.
    await revealInSheet(tester, find.text('Next badge at Level ${data.userStats.nextLevel}'));
    expect(find.textContaining('no badge list yet'), findsOneWidget);

    // The ledger breakdown, grouped by the server's own reason strings.
    await revealInSheet(tester, find.text('Recent activity'));
    await revealInSheet(tester, find.text('Exams'));
    expect(find.text('Assignments'), findsOneWidget);
    expect(find.text('Daily check-in'), findsOneWidget);
  });

  testWidgets('the streak sheet draws a calendar over the server window', (WidgetTester tester) async {
    await pumpSheet(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showStreakSheet(context, data),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('${data.userStats.streak}-day streak'), findsOneWidget);
    expect(find.text('Longest'), findsOneWidget);
    expect(find.text('Earned XP'), findsOneWidget);
    // The copy must not claim the streak tracks app opens: `loginDates` is built
    // from gamification history rows.
    await revealInSheet(tester, find.textContaining('Opening the app on its own'));
  });

  testWidgets('the points sheet says there is no breakdown', (WidgetTester tester) async {
    await pumpSheet(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showPointsSheet(context, data),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Points'), findsWidgets);
    expect(find.textContaining('no per-activity points breakdown'), findsOneWidget);
    expect(find.text('Decides your level'), findsOneWidget);
  });

  testWidgets('the daily claim sheet explains the streak bonus', (WidgetTester tester) async {
    await pumpSheet(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showClaimSheet(context: context, data: data, isBonus: false),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Daily streak reward'), findsOneWidget);
    expect(find.text('Available to claim right now.'), findsOneWidget);
    expect(find.text('How the amount is worked out'), findsOneWidget);
    // One rung per point of the streak bonus, from zero up to the cap.
    await revealInSheet(tester, find.text('+\$0'));
    expect(find.text('+\$4'), findsOneWidget);
  });

  testWidgets('the bonus sheet says the school controls it', (WidgetTester tester) async {
    await pumpSheet(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showClaimSheet(context: context, data: data, isBonus: true),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('How this works'), findsOneWidget);
    expect(find.textContaining('setting your school controls'), findsOneWidget);
  });

  testWidgets('the standing chip is the route into the leaderboard', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((Ref ref) async => data),
          xpHistoryProvider.overrideWith((Ref ref) async => ledger),
          examListProvider.overrideWith(_EmptyExamList.new),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const DashboardScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The chip is the only place the dashboard states a rank, so it must lead
    // somewhere rather than just looking tappable.
    expect(find.text('#${data.sectionLeaderboards.first.userRank} of ${data.sectionLeaderboards.first.totalPlayers}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dashboard hero exposes a tap target for each sheet', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((Ref ref) async => data),
          xpHistoryProvider.overrideWith((Ref ref) async => ledger),
          examListProvider.overrideWith(_EmptyExamList.new),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const DashboardScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    // The hero's three numbers and the level ring are the discoverable entry
    // points; without them the sheets would have no way in.
    await tester.tap(find.text('Season XP'));
    await tester.pumpAndSettle();
    await revealInSheet(tester, find.text('Recent activity'));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Day streak'));
    await tester.pumpAndSettle();
    expect(find.text('Longest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}