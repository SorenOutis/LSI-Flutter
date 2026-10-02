import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsi_flutter/core/network/api_client.dart';
import 'package:lsi_flutter/core/network/fake/fake_api_adapter.dart';
import 'package:lsi_flutter/core/storage/token_storage.dart';
import 'package:lsi_flutter/core/utils/json_parsing.dart';
import 'package:lsi_flutter/features/calendar/domain/calendar_data.dart';
import 'package:lsi_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:lsi_flutter/features/exams/data/exam_repository.dart';

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

/// Exercises the fake backend through the real ApiClient, so the adapter,
/// interceptors and repository parsing are all on the path.
ApiClient _client() {
  final ApiClient client = ApiClient(
    tokenStorage: _MemoryTokenStorage(),
    dio: Dio(),
  );
  client.raw.httpClientAdapter = FakeApiAdapter();
  return client;
}

void main() {
  test('repository paths resolve to the backend /api/v1 prefix', () {
    // The Laravel app mounts its token API at /api/v1 and the base URL carries
    // that prefix, so a repository path must be relative to it. Dio
    // concatenates rather than replaces, so a path that still started with
    // /api would go out as /api/v1/api/... and 404 against every endpoint.
    final client = _client();

    final String uri = RequestOptions(
      path: '/auth/login',
      baseUrl: client.raw.options.baseUrl,
    ).uri.toString();

    expect(uri, 'http://10.0.2.2:8000/api/v1/auth/login');
    expect(uri, isNot(contains('/api/v1/api/')));
  });

  test('login returns a token and a parseable user', () async {
    final Map<String, dynamic> json = await _client().postJson(
      '/api/auth/login',
      body: <String, dynamic>{'email': 'student@lsi.test', 'password': 'password123'},
    );

    expect(json['token'], isA<String>());
    expect((json['token'] as String).isNotEmpty, isTrue);
    expect(json.asMap('user')['email'], 'student@lsi.test');
  });

  test('dashboard payload parses into a full DashboardData', () async {
    final DashboardRepository repository = DashboardRepository(_client());
    final data = await repository.fetch();

    // Level is derived from the season total, never stored independently.
    expect(data.userStats.level, (data.userStats.totalXP ~/ 100) + 1);
    expect(data.userStats.maxXPForLevel, 100);
    expect(data.userStats.streak, 7);
    expect(data.loginDates, isNotEmpty);
    expect(data.announcements, hasLength(2));
    expect(data.assignments, hasLength(3));
    expect(data.upcomingExams, isNotEmpty);
    expect(data.sectionLeaderboards, hasLength(1));
    expect(data.claimXp.canClaim, isTrue);
    expect(data.availableSeasons, hasLength(2));
  });

  test('exam list groups cards and detail carries every question type', () async {
    final ExamRepository repository = ExamRepository(_client());

    final page = await repository.listExams();
    expect(page.groups, hasLength(2));
    expect(page.hasMore, isFalse);
    expect(page.groups.first.exams.first.partsCount, 2);

    final detail = await repository.fetchDetail(101);
    expect(detail.parts, hasLength(2));

    final types = detail.parts.first.questions.map((q) => q.type.wireValue).toSet();
    expect(types, containsAll(<String>['multiple_choice', 'identification', 'enumeration', 'true_false', 'matching']));
  });

  test('autosave, resume and submit round-trip through fake state', () async {
    final ExamRepository repository = ExamRepository(_client());

    // Start the clock, then autosave a partial draft.
    final clock = await repository.startPart(examId: 101, partId: 201);
    expect(clock.deadline, isNotNull);

    await repository.saveAnswers(
      examId: 101,
      partId: 201,
      changed: <int, Object?>{1: 1, 2: 'Manila'},
    );

    // Re-fetching the exam must show the saved answers as a resumable draft.
    final resumed = await repository.fetchDetail(101);
    expect(resumed.answerDrafts[201]?.answers, containsPair(1, 1));
    expect(resumed.answerDrafts[201]?.answers, containsPair(2, 'Manila'));

    // The deadline is written once and must not move on a second call.
    final again = await repository.startPart(examId: 101, partId: 201);
    expect(again.deadline, clock.deadline);

    // Submitting the correct answers scores full marks on the keyed items.
    final result = await repository.submitPart(
      examId: 101,
      partId: 201,
      answers: <int, Object?>{
        1: 1,
        2: 'Manila',
        3: <String>['A', 'C'],
        4: true,
        5: 'B',
      },
    );
    expect(result.status, 'graded');
    expect(result.score, 12);
    expect(result.isPendingGrading, isFalse);

    // The submission is now visible as a part status and in the exam payload.
    final status = await repository.partStatus(examId: 101, partId: 201);
    expect(status.isSettled, isTrue);
    expect(status.scored, isTrue);

    final after = await repository.fetchDetail(101);
    expect(after.isPartSubmitted(201), isTrue);
    expect(after.submittedCount, 1);
    expect(after.isFullySubmitted, isFalse);
  });

  test('unknown routes surface as a 404 rather than a silent empty map', () async {
    await expectLater(
      _client().getJson('/api/nope'),
      throwsA(isA<Object>()),
    );
  });

  test('fake dashboard data drives a populated calendar', () async {
    // The calendar has no endpoint of its own; it derives from the dashboard
    // payload, so the fake data must supply the fields it reads.
    final data = await DashboardRepository(_client()).fetch();
    final calendar = CalendarData.fromDashboard(data);

    expect(calendar.isEmpty, isFalse);

    // Exams and assignments must both land on the timeline.
    expect(calendar.events.any((CalendarEvent e) => e.kind.isExam), isTrue);
    expect(calendar.events.any((CalendarEvent e) => e.kind.isAssignment), isTrue);

    // The 90-day login set becomes activity days and per-day events.
    expect(calendar.daysWithActivity, isNotEmpty);

    // There must be something in the month being shown, otherwise the grid
    // renders empty while the dashboard above it is full.
    expect(calendar.eventCountIn(calendar.focusedMonth) + calendar.daysWithActivity.length, greaterThan(0));

    // The agenda must not be empty starting from today.
    expect(calendar.agendaFrom(DateTime.now()), isNotEmpty);
  });
}
