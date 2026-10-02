import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

/// An in-memory stand-in for the Laravel API.
///
/// Enabled with `--dart-define=USE_FAKE_API=true`. It answers every endpoint the
/// app actually calls so the dashboard, exam list, taking, autosave, submit and
/// review flows can all be driven without a running backend.
///
/// It is stateful on purpose: drafts, deadlines and submissions persist for the
/// life of the process, so resuming a part or reloading an exam behaves the way
/// the real thing does instead of snapping back to a pristine payload.
class FakeBackend {
  FakeBackend();

  static const String _token = 'fake-api-token-do-not-use-in-production';

  /// Question number -> correct answer, per part id. Used to score submissions.
  static const Map<int, Map<int, Object?>> _keys = <int, Map<int, Object?>>{
    201: <int, Object?>{1: 1, 2: 'Manila', 3: <String>['A', 'C'], 4: true, 5: 'B'},
    202: <int, Object?>{6: 0, 7: 'Sphere', 8: 'Two'},
    203: <int, Object?>{9: 1},
    204: <int, Object?>{10: 'Jose Rizal', 11: true},
  };

  final Map<int, Map<int, Object?>> _drafts = <int, Map<int, Object?>>{};
  final Map<int, DateTime> _deadlines = <int, DateTime>{};
  final Map<int, Map<String, dynamic>> _submissions = <int, Map<String, dynamic>>{};

  bool _claimedDaily = false;
  bool _claimedBonus = false;
  bool _blurLeaderboard = false;
  double _totalXp = 2480;

  /// The student's streak. `StreakService` advances it on a dashboard visit, so
  /// it is a visit counter rather than a record of opening the app.
  static const int _streak = 7;

  /// `ClaimXpService::claimAmount()` — a base amount plus a streak bonus that
  /// caps at [ClaimXpService::MAX_STREAK_BONUS] of 4, one point per 5 days.
  ///
  /// The base comes from the `daily_claim_base_xp` setting (default 1); raised
  /// here so the claim amount is worth reading in the UI.
  static const int _dailyClaimBaseXp = 10;
  static const int _maxStreakBonus = 4;

  static int get _dailyClaimAmount =>
      _dailyClaimBaseXp + (_streak ~/ 5).clamp(0, _maxStreakBonus);

  /// `SectionProgress::levelFromExp()` — the level is never stored
  /// independently, it is recomputed from the season total on every save.
  ///
  /// Deriving it here rather than hard-coding keeps the dashboard payload self
  /// consistent: claiming XP moves the total, and a fixed level would then
  /// contradict the XP it is supposed to be a function of.
  int get _levelFromExp => (_totalXp ~/ 100) + 1;

  /// `BonusXpService::bonusXp()` — a flat `daily_claim_bonus_xp` setting, which
  /// only applies at all when `daily_claim_bonus_enabled` is on.
  static const int _bonusClaimXp = 50;

  /// Session id -> its turns, oldest first. Mutable on purpose: a reply the
  /// student sends during a demo has to still be there after leaving the thread
  /// and coming back, exactly as the real history does.
  late final Map<int, List<Map<String, dynamic>>> _chats = _seedChats();

  /// Monotonic id for turns appended at runtime. Seeded turns start well below it
  /// so an appended turn always sorts after everything already stored.
  int _nextMessageId = 900;

  /// Handles one request and decodes the body, which the adapter passes through.
  Future<FakeResponse> handle(RequestOptions options, String? rawBody) async {
    // Enough delay to make spinners and skeletons visible instead of flashing.
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final Object? decoded = rawBody == null || rawBody.isEmpty ? null : jsonDecode(rawBody);
    final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    final String path = options.path;
    final String method = options.method.toUpperCase();

    // `options.path` is whatever the repository passed to the client, so it
    // does NOT include the base URL's `/api/v1`. Drop a leading `api` segment
    // when one is present so a route matches whether the caller used
    // `/auth/login` or `/api/auth/login`.
    final List<String> segments = path
        .split('/')
        .where((String s) => s.isNotEmpty && s != 'api' && s != 'v1')
        .toList(growable: false);

    if (method == 'POST' && segments.join('/') == 'auth/login') {
      final String email = body['email'] is String ? body['email'] as String : 'student@lsi.test';
      return FakeResponse.ok(<String, dynamic>{
        'token': _token,
        'user': _userJson(email: email),
      });
    }

    if (method == 'POST' && segments.join('/') == 'auth/register') {
      final String email = body['email'] is String ? body['email'] as String : 'student@lsi.test';
      final String first = body['first_name'] is String ? body['first_name'] as String : 'Juan';
      final String last = body['last_name'] is String ? body['last_name'] as String : 'Dela Cruz';
      return FakeResponse.ok(<String, dynamic>{
        'token': _token,
        'user': _userJson(email: email, name: '$first $last'),
      });
    }

    if (method == 'GET' && segments.join('/') == 'user') {
      return FakeResponse.ok(_userJson());
    }

    if (method == 'POST' && segments.join('/') == 'auth/logout') {
      return FakeResponse.ok(<String, dynamic>{'message': 'Signed out.'});
    }

    if (method == 'GET' && segments.join('/') == 'dashboard') {
      return FakeResponse.ok(_dashboard());
    }

    if (method == 'GET' && segments.join('/') == 'grades') {
      return FakeResponse.ok(_grades());
    }

    if (method == 'GET' && segments.join('/') == 'assignments') {
      return FakeResponse.ok(_assignments());
    }

    if (method == 'GET' && segments.join('/') == 'leaderboard') {
      return FakeResponse.ok(_leaderboard());
    }

    // The ledger. The real route is `/users/{public_id}/xp-history`;
    // `/xp-history/{user}` is bound to the numeric primary key by `whereNumber`,
    // so the public_id form is the only one a client holding a public id can use.
    if (method == 'GET' &&
        (segments.length == 2 && segments[0] == 'xp-history' ||
            segments.length == 3 && segments[0] == 'users' && segments[2] == 'xp-history')) {
      return FakeResponse.ok(_xpHistory());
    }

    if (method == 'POST' && segments.join('/') == 'leaderboard/toggle-blur') {
      _blurLeaderboard = !_blurLeaderboard;
      return FakeResponse.ok(<String, dynamic>{'blur_leaderboard': _blurLeaderboard});
    }

    // /chats
    if (method == 'GET' && segments.join('/') == 'chats') {
      return FakeResponse.ok(_chatSessions());
    }

    // Design-first create: POST /chats {title?, message?} -> {id, title}.
    // Backend later persists with source=history.
    if (method == 'POST' && segments.join('/') == 'chats') {
      final String title = body['title'] is String ? (body['title'] as String).trim() : '';
      final String first = body['message'] is String ? (body['message'] as String).trim() : '';
      final int id = _nextChatSessionId++;
      _chats[id] = <Map<String, dynamic>>[];
      _chatTitles[id] = title.isNotEmpty ? title : (first.isNotEmpty ? _titleFrom(first) : 'New chat');
      _chatSources[id] = 'history';
      if (first.isNotEmpty) {
        final String iso = DateTime.now().toUtc().toIso8601String();
        _chats[id]!.add(<String, dynamic>{'id': _nextMessageId++, 'role': 'user', 'content': first, 'thinking': null, 'createdAt': iso});
        _chats[id]!.add(<String, dynamic>{
          'id': _nextMessageId++,
          'role': 'assistant',
          'content': _echoReply(first),
          'thinking': null,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
      return FakeResponse.ok(<String, dynamic>{'id': id, 'title': _chatTitles[id]});
    }

    // /chats/{session} — DELETE (design) + PATCH rename (design).
    if (segments.length == 2 && segments[0] == 'chats' && int.tryParse(segments[1]) != null) {
      final int sid = int.parse(segments[1]);
      if (!_chats.containsKey(sid)) return FakeResponse.notFound('Conversation not found.');
      if (method == 'DELETE') {
        _chats.remove(sid);
        _chatTitles.remove(sid);
        _chatSources.remove(sid);
        return FakeResponse.ok(<String, dynamic>{'deleted': true});
      }
      if (method == 'PATCH') {
        final String title = body['title'] is String ? (body['title'] as String).trim() : '';
        if (title.isEmpty) return FakeResponse.notFound('A title is required.');
        _chatTitles[sid] = title;
        return FakeResponse.ok(<String, dynamic>{'id': sid, 'title': title});
      }
    }

    // /chats/{session}/messages — segments: 0=chats 1=id 2=messages
    if (segments.length == 3 && segments[0] == 'chats' && segments[2] == 'messages') {
      final int? sessionId = int.tryParse(segments[1]);
      if (sessionId == null || !_chats.containsKey(sessionId)) {
        return FakeResponse.notFound('Conversation not found.');
      }

      if (method == 'GET') {
        return FakeResponse.ok(_chatMessages(sessionId, options.queryParameters['before_id']));
      }

      if (method == 'POST') {
        final String message = body['message'] is String ? body['message'] as String : '';
        if (message.trim().isEmpty) {
          return FakeResponse.notFound('A message is required.');
        }
        return FakeResponse.ok(_chatSend(sessionId, message.trim()));
      }
    }

    if (method == 'POST' && segments.join('/') == 'claim-xp') {
      final bool already = _claimedDaily;
      final int amount = _dailyClaimAmount;
      if (!already) {
        _claimedDaily = true;
        _totalXp += amount;
      }
      return FakeResponse.ok(<String, dynamic>{
        'claimed': !already,
        'amount': already ? 0 : amount,
        'total_xp': _totalXp,
        'streak': _streak,
      });
    }

    if (method == 'POST' && segments.join('/') == 'claim-bonus-xp') {
      final bool already = _claimedBonus;
      if (!already) {
        _claimedBonus = true;
        _totalXp += _bonusClaimXp;
      }
      return FakeResponse.ok(<String, dynamic>{
        'claimed': !already,
        'amount': already ? 0 : _bonusClaimXp,
        'total_xp': _totalXp,
        'streak': _streak,
      });
    }

    if (method == 'GET' && segments.join('/') == 'exams') {
      return FakeResponse.ok(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'seasonName': 'First Semester', 'exams': _openExams()},
          <String, dynamic>{'seasonName': 'Midterms', 'exams': _closedExams()},
        ],
        'meta': <String, dynamic>{'hasMore': false, 'nextCursor': null},
      });
    }

    // /exams/{id}
    if (method == 'GET' && segments.length == 2 && segments[0] == 'exams') {
      final int? id = int.tryParse(segments[1]);
      if (id != null && _exam(id) != null) return FakeResponse.ok(_examDetail(id));
    }

    // /exams/{id}/parts/{partId}/{start|answers|submit|status}
    //
    // Indices: 0=exams 1=id 2=parts 3=partId 4=action
    if (method == 'POST' && segments.length == 5 && segments[0] == 'exams' && segments[2] == 'parts' && segments[4] == 'start') {
      final int? partId = int.tryParse(segments[3]);
      if (partId == null) return FakeResponse.notFound('Exam part not found.');

      // The deadline is written once and never moves, mirroring the real server
      // so reloads cannot be used to buy extra time.
      final DateTime deadline = _deadlines[partId] ?? DateTime.now().add(const Duration(minutes: 90));
      _deadlines[partId] = deadline;

      return FakeResponse.ok(<String, dynamic>{
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'deadline': deadline.toUtc().toIso8601String(),
      });
    }

    // /exams/{id}/parts/{partId}/answers
    if (method == 'PUT' && segments.length == 5 && segments[0] == 'exams' && segments[2] == 'parts' && segments[4] == 'answers') {
      final int? partId = int.tryParse(segments[3]);
      if (partId == null) return FakeResponse.notFound('Exam part not found.');

      final Map<int, Object?> draft = _drafts.putIfAbsent(partId, () => <int, Object?>{});
      int answered = 0;

      for (final Object? raw in (body['answers'] as List<Object?>? ?? const <Object?>[])) {
        if (raw is! Map<String, dynamic>) continue;
        final Object? number = raw['question_number'];
        if (number is! num) continue;
        draft[number.toInt()] = raw['answer'];
      }

      for (final Object? value in draft.values) {
        if (value is String && value.trim().isNotEmpty) {
          answered++;
        } else if (value is List) {
          if (value.isNotEmpty) answered++;
        } else if (value != null) {
          answered++;
        }
      }

      return FakeResponse.ok(<String, dynamic>{'answered_count': answered});
    }

    // /exams/{id}/parts/{partId}/submit
    if (method == 'POST' && segments.length == 5 && segments[0] == 'exams' && segments[2] == 'parts' && segments[4] == 'submit') {
      final int? partId = int.tryParse(segments[3]);
      if (partId == null) return FakeResponse.notFound('Exam part not found.');

      final Map<int, Object?> draft = _drafts.putIfAbsent(partId, () => <int, Object?>{});
      for (final Object? raw in (body['answers'] as List<Object?>? ?? const <Object?>[])) {
        if (raw is! Map<String, dynamic>) continue;
        final Object? number = raw['question_number'];
        if (number is! num) continue;
        draft[number.toInt()] = raw['answer'];
      }

      final double max = _pointsForPart(partId);
      final double score = _score(partId, draft, max);
      final int submissionId = 9000 + partId;

      _submissions[partId] = <String, dynamic>{
        'id': submissionId,
        'exam_part_id': partId,
        'status': 'graded',
        // A string here, matching the decimal:2 cast on the real endpoint.
        'score': score.toStringAsFixed(2),
        'is_late': false,
        'grading_failed': false,
        'answers': _answerArray(draft),
      };

      return FakeResponse.ok(<String, dynamic>{
        'submission_id': submissionId,
        'exam_part_id': partId,
        'status': 'graded',
        'score': score,
        'is_late': false,
        'awaiting_teacher_review': false,
        'xp_award': _xpAward(score, max),
      });
    }

    // /exams/{id}/parts/{partId}/status
    if (method == 'GET' && segments.length == 5 && segments[0] == 'exams' && segments[2] == 'parts' && segments[4] == 'status') {
      final int? partId = int.tryParse(segments[3]);
      if (partId == null) return FakeResponse.notFound('Exam part not found.');

      final Map<String, dynamic>? submission = _submissions[partId];
      if (submission == null) {
        return FakeResponse.ok(<String, dynamic>{'status': 'not_submitted'});
      }

      final double max = _pointsForPart(partId);
      final double score = double.parse(submission['score'] as String);

      return FakeResponse.ok(<String, dynamic>{
        'status': 'graded',
        'scored': true,
        'score': score,
        'is_late': false,
        'grading_failed': false,
        'awaiting_teacher_review': false,
        'xp_award': _xpAward(score, max),
      });
    }

    // /exams/{id}/review
    if (method == 'GET' && segments.length == 3 && segments[0] == 'exams' && segments[2] == 'review') {
      final int? id = int.tryParse(segments[1]);
      final Map<String, dynamic>? exam = id == null ? null : _exam(id);
      if (exam == null) return FakeResponse.notFound('Exam not found.');

      return FakeResponse.ok(<String, dynamic>{
        'exam': <String, dynamic>{'id': exam['id'], 'title': exam['title']},
        'submissions': <Map<String, dynamic>>[
          for (final Map<String, dynamic> submission in _submissions.values) submission,
        ],
      });
    }

    return FakeResponse.notFound('No fake route for $method $path.');
  }

  Map<String, dynamic> _userJson({String email = 'student@lsi.test', String name = 'Juan Dela Cruz'}) {
    return <String, dynamic>{
      'id': 1,
      'public_id': 'LSI-2026-0001',
      'name': name,
      'email': email,
      'first_name': name.split(' ').first,
      'last_name': name.split(' ').length > 1 ? name.split(' ').last : '',
      'middle_name': null,
      'current_streak': _streak,
      'level': _levelFromExp,
      'exp': _totalXp,
    };
  }

  Map<String, dynamic> _dashboard() {
    final DateTime now = DateTime.now();

    return <String, dynamic>{
      'userStats': <String, dynamic>{
        'totalXP': _totalXp,
        'level': _levelFromExp,
        'currentXP': _totalXp % 100,
        'maxXPForLevel': 100,
        'points': 340,
        'streak': _streak,
        'longestStreak': 21,
      },
      'loginDates': <Map<String, dynamic>>[
        for (int i = 0; i < 90; i++)
          if (_isActiveDay(i))
            <String, dynamic>{
              'date': now.subtract(Duration(days: i)).toIso8601String().substring(0, 10),
            },
      ],
      'announcements': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'title': 'Midterm exam schedule is up',
          'description': 'Check the Exams tab for your assigned set and part order.',
          'link': null,
          'sectionName': 'BSED Mathematics',
          'createdAt': 'Sep 01, 2026',
        },
        <String, dynamic>{
          'id': 2,
          'title': 'Library week',
          'description': 'The main library will close early on Friday.',
          'link': null,
          'sectionName': null,
          'createdAt': 'Aug 28, 2026',
        },
      ],
      // One of each row state — pending, overdue and graded — so the dashboard's
      // assignment styling can be seen end to end without a real backend.
      'assignments': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 12,
          'title': 'Reading Response: Limits',
          'description': 'Two paragraphs.',
          'dueDate': 'Sep 28, 2026',
          'dueAtIso': now.subtract(const Duration(days: 4)).toIso8601String(),
          'isOverdue': true,
          'submitted': false,
          'status': 'Pending',
          'grade': null,
        },
        <String, dynamic>{
          'id': 11,
          'title': 'Problem Set 4: Integrals',
          'description': 'Show all work.',
          'dueDate': 'in 3 days',
          'dueAtIso': now.add(const Duration(days: 3)).toIso8601String(),
          'isOverdue': false,
          'submitted': false,
          'status': 'Pending',
          'grade': null,
        },
        <String, dynamic>{
          'id': 10,
          'title': 'Quiz 3: Derivatives',
          'description': null,
          'dueDate': 'Aug 25, 2026',
          'dueAtIso': now.subtract(const Duration(days: 6)).toIso8601String(),
          'isOverdue': false,
          'submitted': true,
          'status': 'Graded',
          'grade': '18/20',
        },
      ],
      'upcomingExams': _openExams()
          .map((Map<String, dynamic> card) => _toUpcoming(card))
          .toList(growable: false),
      'sectionLeaderboards': <Map<String, dynamic>>[
        _sectionLeaderboard(sectionId: 1, sectionName: 'BSED Mathematics - A', userRank: 4, totalPlayers: 62),
      ],
      'claimXp': <String, dynamic>{
        'canClaim': !_claimedDaily,
        'amount': _dailyClaimAmount,
        // `nextClaimAt` is the day after the last claim, at midnight — not a
        // rolling cooldown — so a claim made this morning reads as tomorrow.
        'nextClaimAt': _claimedDaily
            ? DateTime(now.year, now.month, now.day + 1).toIso8601String()
            : null,
        'showPrompt': !_claimedDaily,
      },
      'bonusXp': <String, dynamic>{
        'canClaim': !_claimedBonus,
        'amount': _bonusClaimXp,
        'nextClaimAt': null,
        'showPrompt': !_claimedBonus,
      },
      'availableSeasons': <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'First Semester'},
        <String, dynamic>{'id': 2, 'name': 'Midterms'},
      ],
      'activeSeason': <String, dynamic>{'id': 1, 'name': 'First Semester'},
      // Design-first: drives the restore banner preview. Flip `simulateBroken`
      // to true to test the broken-streak design without a backend.
      'streakRestore': _streakRestorePreview(),
    };
  }

  /// Toggle this to true to preview the broken-streak banner + sheet.
  bool simulateBrokenStreak = false;

  Map<String, dynamic> _streakRestorePreview() {
    if (simulateBrokenStreak) {
      return <String, dynamic>{
        'isBroken': true,
        'canRestore': true,
        'restoreCost': 100,
        'pointsBalance': 340,
        'previousStreak': _streak,
        'breakLabel': 'yesterday',
        'deadlineLabel': 'Restore within 48 hours · expires tomorrow',
        'freezeAvailable': false,
      };
    }
    return <String, dynamic>{
      'isBroken': false,
      'canRestore': true,
      'restoreCost': 100,
      'pointsBalance': 340,
      'previousStreak': _streak,
      'breakLabel': 'yesterday',
      'deadlineLabel': 'Restore within 48 hours',
      'freezeAvailable': true,
    };
  }

  /// A believable roster. Placeholder names like "Student 3" make a leaderboard
  /// impossible to eyeball, which is the one thing a fixture is for.
  static const List<String> _names = <String>[
    'Ana Reyes',
    'Miguel Santos',
    'Bea Villanueva',
    'Carlo Mendoza',
    'Liza Bautista',
    'Paolo Cruz',
    'Mika Domingo',
    'Sofia Ramos',
  ];

  /// A section leaderboard in the shape `LeaderboardService::forViewer` emits.
  /// Used by both `/dashboard` and `/leaderboard` so the two never drift.
  Map<String, dynamic> _sectionLeaderboard({
    required int sectionId,
    required String sectionName,
    required int userRank,
    required int totalPlayers,
    bool enabled = true,
    int size = 5,
  }) {
    return <String, dynamic>{
      'sectionId': sectionId,
      'sectionName': sectionName,
      'leaderboardEnabled': enabled,
      'userRank': userRank,
      'totalPlayers': totalPlayers,
      'users': <Map<String, dynamic>>[
        for (int rank = 1; rank <= size; rank++)
          <String, dynamic>{
            'id': rank,
            'publicId': 'LSI-2026-${rank.toString().padLeft(4, '0')}',
            'name': rank == userRank ? 'Juan Dela Cruz' : _names[(rank - 1) % _names.length],
            'xp': rank == userRank ? _totalXp : 5200 - rank * 400,
            'level': rank == userRank ? 12 : 14,
            'xpProgress': (5200 - rank * 400) % 100,
            'streak': rank * 2,
            'trend': rank.isEven ? 'up' : 'stable',
            'isCurrentUser': rank == userRank,
            // `blur_leaderboard` is a per-user column, so only the viewer's own
            // row is affected by their privacy toggle — matching the service.
            'blurred': rank == userRank && _blurLeaderboard,
          },
      ],
    };
  }

  /// `/grades` — mirrors `GradeController::buildGradesData`: one part-graded
  /// college subject, one complete one, and one senior-high subject that reports
  /// `semesterGrades` instead of per-period grades.
  Map<String, dynamic> _grades() {
    Map<String, dynamic> grade(int id, String score, String updatedAt, [String? remarks]) {
      return <String, dynamic>{
        'id': id,
        // `decimal:2` / `number_format()` arrive as strings, not numbers.
        'score': score,
        'maxScore': '100.00',
        'percentage': double.parse(score),
        'remarks': remarks,
        'updatedAt': updatedAt,
      };
    }

    return <String, dynamic>{
      'subjectGrades': <Map<String, dynamic>>[
        <String, dynamic>{
          'subject': 'General Mathematics',
          'section': <String, dynamic>{
            'id': 1,
            'name': 'BSED Mathematics - A',
            'schoolLevel': 'college',
            'schoolLevelLabel': 'College',
          },
          'periods': <Map<String, dynamic>>[
            <String, dynamic>{'key': 'prelim', 'label': 'Prelim'},
            <String, dynamic>{'key': 'midterm', 'label': 'Midterm'},
            <String, dynamic>{'key': 'semifinal', 'label': 'Semi-Final'},
            <String, dynamic>{'key': 'final', 'label': 'Final'},
          ],
          'periodGrades': <Map<String, dynamic>>[
            <String, dynamic>{'key': 'prelim', 'label': 'Prelim', 'grade': grade(1, '88.00', 'Sep 12, 2026', 'Solid work')},
            <String, dynamic>{'key': 'midterm', 'label': 'Midterm', 'grade': grade(2, '91.50', 'Oct 01, 2026')},
            <String, dynamic>{'key': 'semifinal', 'label': 'Semi-Final', 'grade': null},
            <String, dynamic>{'key': 'final', 'label': 'Final', 'grade': null},
          ],
          'semesterGrades': <Map<String, dynamic>>[],
          'gradedPeriods': 2,
          'totalPeriods': 4,
          'isComplete': false,
          'currentAverage': 89.75,
          'semesterGrade': null,
        },
        <String, dynamic>{
          'subject': 'Physical Education 1',
          'section': <String, dynamic>{
            'id': 1,
            'name': 'BSED Mathematics - A',
            'schoolLevel': 'college',
            'schoolLevelLabel': 'College',
          },
          'periods': <Map<String, dynamic>>[
            <String, dynamic>{'key': 'prelim', 'label': 'Prelim'},
            <String, dynamic>{'key': 'midterm', 'label': 'Midterm'},
            <String, dynamic>{'key': 'semifinal', 'label': 'Semi-Final'},
            <String, dynamic>{'key': 'final', 'label': 'Final'},
          ],
          'periodGrades': <Map<String, dynamic>>[
            <String, dynamic>{'key': 'prelim', 'label': 'Prelim', 'grade': grade(3, '95.00', 'Sep 10, 2026')},
            <String, dynamic>{'key': 'midterm', 'label': 'Midterm', 'grade': grade(4, '96.00', 'Sep 28, 2026')},
            <String, dynamic>{'key': 'semifinal', 'label': 'Semi-Final', 'grade': grade(5, '94.00', 'Nov 08, 2026')},
            <String, dynamic>{'key': 'final', 'label': 'Final', 'grade': grade(6, '97.00', 'Dec 12, 2026')},
          ],
          'semesterGrades': <Map<String, dynamic>>[],
          'gradedPeriods': 4,
          'totalPeriods': 4,
          'isComplete': true,
          'currentAverage': 95.5,
          'semesterGrade': 95.5,
        },
        <String, dynamic>{
          'subject': 'English for Academic Purposes',
          'section': <String, dynamic>{
            'id': 2,
            'name': 'STEM 11 - Rizal',
            'schoolLevel': 'senior_high',
            'schoolLevelLabel': 'Senior High',
          },
          'periods': <Map<String, dynamic>>[],
          'periodGrades': <Map<String, dynamic>>[],
          'semesterGrades': <Map<String, dynamic>>[
            <String, dynamic>{
              'key': 's1',
              'label': 'First Semester',
              'quarters': <Map<String, dynamic>>[
                <String, dynamic>{'key': 'q1', 'label': 'Quarter 1', 'grade': grade(7, '92.00', 'Sep 05, 2026')},
                <String, dynamic>{'key': 'q2', 'label': 'Quarter 2', 'grade': grade(8, '94.00', 'Oct 01, 2026')},
              ],
              'finalGrade': 93.0,
            },
            <String, dynamic>{
              'key': 's2',
              'label': 'Second Semester',
              'quarters': <Map<String, dynamic>>[
                <String, dynamic>{'key': 'q3', 'label': 'Quarter 3', 'grade': null},
                <String, dynamic>{'key': 'q4', 'label': 'Quarter 4', 'grade': null},
              ],
              'finalGrade': null,
            },
          ],
          'gradedPeriods': 0,
          'totalPeriods': 0,
          'isComplete': false,
          'currentAverage': null,
          'semesterGrade': null,
        },
      ],
    };
  }

  /// `/assignments` — one entry per state the list must style: overdue,
  /// due soon, awaiting grade, graded with unseen feedback, and group work.
  Map<String, dynamic> _assignments() {
    final DateTime now = DateTime.now();

    Map<String, dynamic> submission({
      required String status,
      String? grade,
      double points = 0,
      double xpEarned = 0,
      String? feedback,
      bool unseen = false,
    }) {
      return <String, dynamic>{
        'submitted': true,
        'status': status,
        'grade': grade,
        'file_path': 'submissions/lab-report.pdf',
        'file_url': null,
        'submitted_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'submitted_by': 1,
        'submitted_by_name': 'Juan Dela Cruz',
        'points': points,
        'xp_earned': xpEarned,
        'feedback': feedback,
        'graded_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'graded_by': 2,
        'feedback_seen_at': null,
        'has_unseen_feedback': unseen,
        'file_extension': 'pdf',
      };
    }

    Map<String, dynamic> assignment({
      required int id,
      required String title,
      String? description,
      required int dueInDays,
      required int points,
      Map<String, dynamic>? submission,
      Map<String, dynamic>? group,
      List<int> groupRange = const <int>[1, 1],
      String course = 'General Mathematics',
    }) {
      return <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'status': 'published',
        'due_date': now.add(Duration(days: dueInDays)).toIso8601String(),
        'points_possible': points,
        'group_rules': <String, dynamic>{'min': groupRange[0], 'max': groupRange[1]},
        'incoming_invite': null,
        'course': <String, dynamic>{'id': 1, 'name': course},
        'sections': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'name': 'BSED Mathematics - A'},
        ],
        'group': group,
        'submission': submission,
      };
    }

    return <String, dynamic>{
      'assignments': <Map<String, dynamic>>[
        assignment(
          id: 31,
          title: 'Reading Response: Limits',
          description: 'Two paragraphs on continuity, in your own words.',
          dueInDays: -4,
          points: 20,
        ),
        assignment(
          id: 32,
          title: 'Lab Report: Projectile Motion',
          description: 'Include the data table and your error analysis.',
          dueInDays: 1,
          points: 25,
          course: 'General Science',
        ),
        assignment(
          id: 33,
          title: 'Problem Set 4: Integrals',
          description: 'Show all work.',
          dueInDays: 3,
          points: 30,
        ),
        assignment(
          id: 34,
          title: 'Group Presentation: Statistics',
          description: 'Groups of three or four; slides are due before the defense.',
          dueInDays: 6,
          points: 40,
          groupRange: <int>[3, 4],
          group: <String, dynamic>{
            'id': 9,
            'created_by': 1,
            'members': <Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'name': 'Juan Dela Cruz', 'avatar': null},
              <String, dynamic>{'id': 5, 'name': 'Liza Bautista', 'avatar': null},
            ],
            'pending_invites': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 3,
                'user': <String, dynamic>{'id': 7, 'name': 'Mika Domingo', 'avatar': null},
                'expires_at': now.add(const Duration(days: 2)).toIso8601String(),
              },
            ],
          },
        ),
        assignment(
          id: 35,
          title: 'Quiz 3: Derivatives',
          dueInDays: -6,
          points: 20,
          submission: submission(
            status: 'graded',
            grade: '18/20',
            points: 18,
            xpEarned: 60,
            feedback: 'Clear work. Mind the sign on question 4.',
            unseen: true,
          ),
        ),
      ],
    };
  }

  /// `/leaderboard` — two sections, one with the board switched off.
  Map<String, dynamic> _leaderboard() {
    return <String, dynamic>{
      'leaderboards': <Map<String, dynamic>>[
        _sectionLeaderboard(sectionId: 1, sectionName: 'BSED Mathematics - A', userRank: 4, totalPlayers: 62, size: 8),
        _sectionLeaderboard(
          sectionId: 2,
          sectionName: 'STEM 11 - Rizal',
          userRank: 2,
          totalPlayers: 38,
          enabled: false,
          size: 8,
        ),
      ],
      'selectedSeason': <String, dynamic>{'id': 1, 'name': 'First Semester'},
    };
  }

  /// `/chats` — the conversation list.
  ///
  /// Mirrors `ChatHistoryController::sessionPage`: summaries only, with the
  /// last message and the turn count derived in SQL on the real server. The
  /// previews here are computed from the stored turns rather than hand-written,
  /// so a message sent during the demo shows up in the list without the fixture
  /// and the payload disagreeing.
  Map<String, dynamic> _chatSessions() {
    final List<Map<String, dynamic>> sessions = <Map<String, dynamic>>[];

    for (final MapEntry<int, List<Map<String, dynamic>>> entry in _chats.entries) {
      final List<Map<String, dynamic>> turns = entry.value;
      if (turns.isEmpty) continue;

      final Map<String, dynamic> last = turns.last;

      sessions.add(<String, dynamic>{
        'id': entry.key,
        'title': _chatTitles[entry.key] ?? 'New chat',
        'source': _chatSources[entry.key],
        'messageCount': turns.length,
        'lastMessage': last['content'],
        'updatedAt': last['createdAt'],
        'updatedAtHuman': _diffForHumans(DateTime.parse(last['createdAt'] as String)),
      });
    }

    sessions.sort((Map<String, dynamic> a, Map<String, dynamic> b) => (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));

    return <String, dynamic>{
      'data': sessions,
      'meta': <String, dynamic>{'hasMore': false, 'nextCursor': null},
    };
  }

  /// `/chats/{session}/messages` — one bounded page, oldest first.
  ///
  /// `before_id` pages backwards exactly as the cursor does, so the thread
  /// screen's "load older turns" path is exercised by the fake too.
  Map<String, dynamic> _chatMessages(int sessionId, Object? beforeId) {
    final List<Map<String, dynamic>> all = _chats[sessionId]!;
    final int? before = beforeId is num ? beforeId.toInt() : int.tryParse('${beforeId ?? ''}');

    final List<Map<String, dynamic>> filtered = before == null
        ? all
        : all.where((Map<String, dynamic> m) => (m['id']! as int) < before).toList();

    // The newest page is the one that matters; the server sends the last 80.
    final List<Map<String, dynamic>> page = filtered.length <= 80
        ? filtered
        : filtered.sublist(filtered.length - 80);

    return <String, dynamic>{
      'data': page,
      'meta': <String, dynamic>{
        'hasMore': filtered.length > page.length,
        'nextBeforeId': filtered.length > page.length ? page.first['id'] : null,
      },
    };
  }

  /// `POST /chats/{session}/messages` — persists both halves of the exchange and
  /// answers with the assistant's text, as the real route does.
  Map<String, dynamic> _chatSend(int sessionId, String message) {
    final List<Map<String, dynamic>> turns = _chats[sessionId]!;
    final String iso = DateTime.now().toUtc().toIso8601String();

    turns.add(<String, dynamic>{
      'id': _nextMessageId++,
      'role': 'user',
      'content': message,
      'thinking': null,
      'createdAt': iso,
    });

    final String answer = _echoReply(message);

    turns.add(<String, dynamic>{
      'id': _nextMessageId++,
      'role': 'assistant',
      'content': answer,
      'thinking': 'Echo checked the student context (sections, current season XP and '
          'recent assignments) before answering, then drafted a worked example and '
          'checked it against the syllabus outcome for this topic.',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    return <String, dynamic>{
      'response': answer,
      'session': <String, dynamic>{'id': sessionId, 'messageCount': turns.length},
    };
  }

  /// A canned reply that acknowledges the question instead of echoing it, so a
  /// demo of the composer reads like a conversation rather than a mirror.
  String _echoReply(String question) {
    final String lower = question.toLowerCase();

    if (lower.contains('deriv')) {
      return 'A derivative measures how fast a quantity changes with respect to another. '
          'Two rules cover most of what you will meet:\n\n'
          '• Power rule — d/dx of xⁿ is n·xⁿ⁻¹.\n'
          '• Product rule — d/dx of f(x)·g(x) is f′(x)·g(x) + f(x)·g′(x).\n\n'
          'For Quiz 3, the chain rule is the one that trips people up: remember to '
          'multiply by the derivative of the inside function. Want me to walk through '
          'any of the questions you got wrong?';
    }

    if (lower.contains('exam') || lower.contains('quiz') || lower.contains('grade')) {
      return 'Exams here open and close on a fixed window and save your answers as you go, '
          'so you can close the app mid-part and pick it back up.\n\n'
          'Two habits that help: read the part instructions before starting — each part '
          'often carries its own time limit — and submit a part before moving to the next '
          'one, since a part left unsubmitted scores zero.\n\n'
          'Anything specific about the format or the topics?';
    }

    return 'Happy to help with that.\n\n'
        'I can see your sections and the assignments you have open, so tell me which '
        'subject this is about and I can work through it step by step — or, if you would '
        'rather just be walked through, ask me to start with the basics.';
  }

  /// Laravel's `diffForHumans()` shape, close enough for the list's time column.
  String _diffForHumans(DateTime then) {
    final Duration age = DateTime.now().toUtc().difference(then.toUtc());

    if (age.inMinutes < 1) return '1 minute ago';
    if (age.inMinutes < 60) return '${age.inMinutes} minutes ago';
    if (age.inHours < 24) return '${age.inHours} ${age.inHours == 1 ? 'hour' : 'hours'} ago';
    if (age.inDays < 7) return '${age.inDays} ${age.inDays == 1 ? 'day' : 'days'} ago';
    if (age.inDays < 30) return '${(age.inDays / 7).floor()} ${age.inDays < 14 ? 'week' : 'weeks'} ago';
    return '${(age.inDays / 30).floor()} months ago';
  }

  /// Titles for the seeded conversations. Held beside the turns rather than in
  /// them so the list keeps one source of truth for a session's name.
  /// Instance (not static const) so design-first create/rename/delete can
  /// mutate it during a demo session.
  final Map<int, String> _chatTitles = <int, String>{
    1: 'Derivatives practice',
    2: 'Essay plan for the Rizal module',
    3: 'Why is the sky blue?',
  };

  /// `source` is where the conversation was started. `widget` means it began in
  /// the Echo panel, `history` on the Chats page itself.
  final Map<int, String?> _chatSources = <int, String?>{
    1: 'widget',
    2: 'history',
    3: null,
  };

  int _nextChatSessionId = 100;

  String _titleFrom(String message) {
    final String oneLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= 42) return oneLine.isEmpty ? 'New chat' : oneLine;
    return '${oneLine.substring(0, 42)}…';
  }

  /// `/users/{public_id}/xp-history`.
  ///
  /// The `reason` strings are the ones the server actually writes — `Daily
  /// Claim`, `Bonus Claim`, `Assignment Graded`, `Exam Submission`, `Season
  /// Reward`, `Admin Adjustment`, plus the three per-component exam reasons — so a
  /// demo of the level sheet groups entries the same way production will. A
  /// negative amount is included on purpose: the ledger has to show a deduction,
  /// and the server labels one with the same `Assignment Graded` reason, so the
  /// grouping cannot rely on the reason to mark it.
  Map<String, dynamic> _xpHistory() {
    final DateTime now = DateTime.now();
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>[0, 50.0, 'Exam Completion XP', 'Calculus Midterm · Part I', 'BSED Mathematics - A'],
      <Object?>[0, 11.0, 'Daily Claim', 'Daily login claim bonus', null],
      <Object?>[1, 60.0, 'Assignment Graded', 'Quiz 3: Derivatives · 18/20', 'BSED Mathematics - A'],
      <Object?>[2, 35.0, 'Assignment Graded', 'Problem Set 3: Sequences', 'BSED Mathematics - A'],
      <Object?>[3, 11.0, 'Daily Claim', 'Daily login claim bonus', null],
      <Object?>[4, -15.0, 'Assignment Graded', 'Problem Set 3: Sequences · late', 'BSED Mathematics - A'],
      <Object?>[5, 120.0, 'Exam Submission', 'Geometry Quiz 1', 'BSED Mathematics - A'],
      <Object?>[6, 50.0, 'Bonus Claim', 'Bonus daily claim', null],
      <Object?>[8, 45.0, 'Assignment Graded', 'Reading Response: Poetry', 'STEM 11 - Rizal'],
      <Object?>[9, 40.0, 'On-time Exam XP', 'Calculus Midterm', 'BSED Mathematics - A'],
      <Object?>[11, 11.0, 'Daily Claim', 'Daily login claim bonus', null],
      <Object?>[14, 25.0, 'Exam Accuracy XP', 'Geometry Quiz 1', 'BSED Mathematics - A'],
      <Object?>[18, 100.0, 'Season Reward', 'Initial progress for Season: First Semester', null],
      <Object?>[21, -20.0, 'Admin Adjustment', 'Late submission review', null],
    ];

    return <String, dynamic>{
      'data': <Map<String, dynamic>>[
        for (int i = 0; i < rows.length; i++)
          <String, dynamic>{
            'id': 100 - i,
            'amount_xp': rows[i][1],
            'reason': rows[i][2],
            'description': rows[i][3],
            'section_name': rows[i][4],
            'created_at': DateFormat('MMM dd, yyyy HH:mm').format(
              now.subtract(Duration(days: rows[i][0]! as int, hours: i % 5 + 1)),
            ),
          },
      ],
      'meta': <String, dynamic>{'hasMore': false, 'nextCursor': null},
    };
  }

  /// A believable activity history for the heatmap: the current streak is
  /// unbroken, there is a 21-day run earlier in the season to match
  /// `longestStreak`, and the rest is scattered. A modulo pattern would render
  /// as an obvious repeating stripe rather than something a person did.
  static bool _isActiveDay(int daysAgo) {
    if (daysAgo < 7) return true;
    if (daysAgo >= 7 && daysAgo <= 9) return false;
    if (daysAgo >= 16 && daysAgo <= 36) return true;
    return (daysAgo * 37) % 100 > 34;
  }

  /// Maps an exam card onto the dashboard's slightly different shape.
  Map<String, dynamic> _toUpcoming(Map<String, dynamic> card) {
    return <String, dynamic>{
      'id': card['id'],
      'title': card['title'],
      'description': card['description'],
      'exam_date': card['exam_date'],
      'starts_at_iso': card['starts_at_iso'],
      'ends_at_iso': card['ends_at_iso'],
      'duration_minutes': card['duration_minutes'],
      'status': card['is_open_now'] == true ? 'Open' : 'Upcoming',
      'parts_count': card['total_parts'],
      'submitted_parts': card['submitted_parts_count'],
      'is_completed': (card['submitted_parts_count'] as int) >= (card['total_parts'] as int),
      'is_open_now': card['is_open_now'],
      'is_upcoming': card['is_upcoming'],
      'has_ended': card['has_ended'],
      'set': card['set'] is Map<String, dynamic>
          ? (card['set'] as Map<String, dynamic>)['title']
          : null,
    };
  }

  Map<String, dynamic>? _exam(int id) {
    for (final Map<String, dynamic> exam in <Map<String, dynamic>>[..._openExamRows(), ..._closedExamRows()]) {
      if (exam['id'] == id) return exam;
    }
    return null;
  }

  List<Map<String, dynamic>> _openExams() => _openExamRows().map(_toCard).toList(growable: false);

  List<Map<String, dynamic>> _closedExams() => _closedExamRows().map(_toCard).toList(growable: false);

  List<Map<String, dynamic>> _openExamRows() {
    final DateTime now = DateTime.now();

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 101,
        'title': 'Calculus Midterm',
        'description': 'Covers limits, derivatives and integrals.',
        'season_name': 'First Semester',
        'section_name': 'BSED Mathematics - A',
        'starts_at_iso': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'ends_at_iso': now.add(const Duration(days: 3)).toIso8601String(),
        'is_open_now': true,
        'is_upcoming': false,
        'has_ended': false,
        'duration_minutes': 90,
        'set': <String, dynamic>{'id': 7, 'title': 'Set B'},
        'exam_date_iso': now.add(const Duration(days: 3)).toIso8601String(),
        'results_available': false,
      },
      <String, dynamic>{
        'id': 102,
        'title': 'Geometry Quiz 2',
        'description': null,
        'season_name': 'First Semester',
        'section_name': 'BSED Mathematics - A',
        'starts_at_iso': now.add(const Duration(days: 2)).toIso8601String(),
        'ends_at_iso': now.add(const Duration(days: 4)).toIso8601String(),
        'is_open_now': false,
        'is_upcoming': true,
        'has_ended': false,
        'duration_minutes': 45,
        'set': <String, dynamic>{'id': 8, 'title': 'Set A'},
        'exam_date_iso': now.add(const Duration(days: 2)).toIso8601String(),
        'results_available': false,
      },
    ];
  }

  List<Map<String, dynamic>> _closedExamRows() {
    final DateTime now = DateTime.now();

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 103,
        'title': 'Algebra Final',
        'description': 'Closed. Results are available.',
        'season_name': 'Midterms',
        'section_name': 'BSED Mathematics - A',
        'starts_at_iso': now.subtract(const Duration(days: 9)).toIso8601String(),
        'ends_at_iso': now.subtract(const Duration(days: 8)).toIso8601String(),
        'is_open_now': false,
        'is_upcoming': false,
        'has_ended': true,
        'duration_minutes': 120,
        'set': <String, dynamic>{'id': 9, 'title': 'Set C'},
        'exam_date_iso': now.subtract(const Duration(days: 9)).toIso8601String(),
        'results_available': false,
      },
      <String, dynamic>{
        'id': 104,
        'title': 'Statistics Prelim',
        'description': 'Submitted and graded.',
        'season_name': 'Midterms',
        'section_name': 'BSED Mathematics - A',
        'starts_at_iso': now.subtract(const Duration(days: 20)).toIso8601String(),
        'ends_at_iso': now.subtract(const Duration(days: 19)).toIso8601String(),
        'is_open_now': false,
        'is_upcoming': false,
        'has_ended': true,
        'duration_minutes': 60,
        'set': <String, dynamic>{'id': 10, 'title': 'Set A'},
        'exam_date_iso': now.subtract(const Duration(days: 20)).toIso8601String(),
        'results_available': true,
      },
    ];
  }

  Map<String, dynamic> _toCard(Map<String, dynamic> row) {
    final int id = row['id'] as int;
    final List<Map<String, dynamic>> parts = _partsFor(id);
    final int submitted = parts.where((Map<String, dynamic> p) => _submissions.containsKey(p['id'] as int)).length;
    final bool ended = row['has_ended'] == true;

    return <String, dynamic>{
      'id': id,
      'title': row['title'],
      'description': row['description'],
      'starts_at_iso': row['starts_at_iso'],
      'ends_at_iso': row['ends_at_iso'],
      'is_open_now': row['is_open_now'],
      'is_upcoming': row['is_upcoming'],
      'has_ended': row['has_ended'],
      'is_locked': ended || (parts.isNotEmpty && submitted >= parts.length),
      'duration_minutes': row['duration_minutes'],
      'total_parts': parts.length,
      'submitted_parts_count': submitted,
      'set': row['set'],
      'results_available': row['results_available'] == true && submitted > 0,
      'section_name': row['section_name'],
      'season_name': row['season_name'],
      'exam_date_iso': row['exam_date_iso'],
      'submissions': <Map<String, dynamic>>[
        for (final Map<String, dynamic> part in parts)
          if (_submissions[part['id'] as int] case final Map<String, dynamic> submission) submission,
      ],
    };
  }

  List<Map<String, dynamic>> _partsFor(int examId) {
    switch (examId) {
      case 101:
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 201,
            'exam_id': 101,
            'title': 'Part I - Objective',
            'instructions': 'Answer every question. Select the best answer.',
            'questions': _objectiveQuestions(),
          },
          <String, dynamic>{
            'id': 202,
            'exam_id': 101,
            'title': 'Part II - Written',
            'instructions': 'Answer in full sentences.',
            'questions': _writtenQuestions(),
          },
        ];
      case 102:
        return <Map<String, dynamic>>[
          <String, dynamic>{'id': 203, 'exam_id': 102, 'title': null, 'instructions': null, 'questions': _shortQuestions()},
        ];
      case 103:
        return <Map<String, dynamic>>[
          <String, dynamic>{'id': 204, 'exam_id': 103, 'title': 'Part I', 'instructions': null, 'questions': _writtenQuestions()},
        ];
      case 104:
        return <Map<String, dynamic>>[
          <String, dynamic>{'id': 205, 'exam_id': 104, 'title': 'Prelim', 'instructions': null, 'questions': _shortQuestions()},
        ];
      default:
        return const <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _objectiveQuestions() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'text': 'What is the derivative of x^3 with respect to x?',
        'type': 'multiple_choice',
        'points': 2,
        'options': <Map<String, dynamic>>[
          <String, dynamic>{'text': 'x'},
          <String, dynamic>{'text': '3x^2'},
          <String, dynamic>{'text': '3x'},
          <String, dynamic>{'text': 'x^2/2'},
        ],
      },
      <String, dynamic>{
        'text': 'The capital of the Philippines is',
        'type': 'identification',
        'points': 2,
        'options': <Map<String, dynamic>>[
          <String, dynamic>{'text': 'Cebu City'},
          <String, dynamic>{'text': 'Manila'},
          <String, dynamic>{'text': 'Davao City'},
          <String, dynamic>{'text': 'Quezon City'},
        ],
      },
      <String, dynamic>{
        'text': 'Give two prime numbers greater than 10.',
        'type': 'enumeration',
        'points': 4,
        'enumeration_items': <Map<String, dynamic>>[
          <String, dynamic>{'points': 2},
          <String, dynamic>{'points': 2},
        ],
      },
      <String, dynamic>{
        'text': 'The graph of a sine function is periodic over the real numbers.',
        'type': 'true_false',
        'points': 1,
        'options': <Map<String, dynamic>>[
          <String, dynamic>{'text': 'True'},
          <String, dynamic>{'text': 'False'},
        ],
      },
      <String, dynamic>{
        'text': 'Match each solid with its Euler characteristic.',
        'type': 'matching',
        'points': 3,
        'matching_items': <Map<String, dynamic>>[
          <String, dynamic>{'index': 1, 'prompt': 'Tetrahedron', 'points': 1},
          <String, dynamic>{'index': 2, 'prompt': 'Torus', 'points': 1},
          <String, dynamic>{'index': 3, 'prompt': 'Cube', 'points': 1},
        ],
        'matching_options': <Map<String, dynamic>>[
          <String, dynamic>{'value': 'A', 'text': '0'},
          <String, dynamic>{'value': 'B', 'text': '2'},
          <String, dynamic>{'value': 'C', 'text': '4'},
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _writtenQuestions() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'text': 'A sphere has radius 3. Find its surface area.',
        'type': 'essay',
        'points': 5,
      },
      <String, dynamic>{
        'text': 'Explain in two sentences why a square is a rectangle.',
        'type': 'essay',
        'points': 4,
      },
      <String, dynamic>{
        'text': 'State the name of the theorem that relates the sides and angles of a triangle.',
        'type': 'essay',
        'points': 3,
      },
    ];
  }

  List<Map<String, dynamic>> _shortQuestions() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'text': 'What is the slope of a horizontal line?',
        'type': 'multiple_choice',
        'points': 2,
        'options': <Map<String, dynamic>>[
          <String, dynamic>{'text': '0'},
          <String, dynamic>{'text': '1'},
          <String, dynamic>{'text': 'Undefined'},
        ],
      },
    ];
  }

  Map<String, dynamic> _examDetail(int examId) {
    final Map<String, dynamic> row = _exam(examId)!;
    final List<Map<String, dynamic>> parts = _partsFor(examId);

    return <String, dynamic>{
      'exam': <String, dynamic>{
        'id': examId,
        'title': row['title'],
        'description': row['description'],
        'starts_at_iso': row['starts_at_iso'],
        'ends_at_iso': row['ends_at_iso'],
        'is_open_now': row['is_open_now'],
        'is_upcoming': row['is_upcoming'],
        'has_ended': row['has_ended'],
        'section_name': row['section_name'],
        'duration_minutes': row['duration_minutes'],
        'set': row['set'],
        'parts': <Map<String, dynamic>>[
          for (final Map<String, dynamic> part in parts)
            <String, dynamic>{
              ...part,
              'points': _pointsOf(part['questions'] as List<Map<String, dynamic>>),
            },
        ],
      },
      'submissions': <String, dynamic>{
        for (final Map<String, dynamic> part in parts)
          if (_submissions[part['id'] as int] case final Map<String, dynamic> submission)
            '${part['id']}': submission,
      },
      'partDeadlines': <String, dynamic>{
        for (final Map<String, dynamic> part in parts)
          if (_deadlines[part['id'] as int] case final DateTime deadline)
            '${part['id']}': <String, dynamic>{'value': deadline.toUtc().toIso8601String()},
      },
      'answerDrafts': <String, dynamic>{
        for (final Map<String, dynamic> part in parts)
          if (_drafts[part['id'] as int] case final Map<int, Object?> draft)
            '${part['id']}': <String, dynamic>{
              'answers': _answerArray(draft),
              'saved_at': DateTime.now().toUtc().toIso8601String(),
            },
      },
      // A fixed award so a graded exam still has something to render; the real
      // endpoint derives these from the submission.
      'xpAward': _hasScored(parts) ? _xpAward(0, 1, totalXp: 120) : null,
    };
  }

  bool _hasScored(List<Map<String, dynamic>> parts) =>
      parts.any((Map<String, dynamic> p) => _submissions.containsKey(p['id'] as int));

  /// Three conversations for `/chats`.
  ///
  /// Timestamps are relative to now so the list's "2 hours ago" column is always
  /// believable, and one conversation crosses midnight so the thread screen's day
  /// separators have something to draw. Session 4 is left empty on purpose: the
  /// server keeps untitled sessions, and the client has to render one without
  /// crashing.
  Map<int, List<Map<String, dynamic>>> _seedChats() {
    final DateTime now = DateTime.now();

    Map<String, dynamic> turn(int id, String role, String content, Duration ago, {String? thinking}) {
      return <String, dynamic>{
        'id': id,
        'role': role,
        'content': content,
        'thinking': thinking,
        'createdAt': now.subtract(ago).toUtc().toIso8601String(),
      };
    }

    return <int, List<Map<String, dynamic>>>{
      1: <Map<String, dynamic>>[
        turn(101, 'user', 'I keep mixing up the product rule and the chain rule. When do I use which?', const Duration(hours: 3, minutes: 12)),
        turn(
          102,
          'assistant',
          'The distinction is what is being differentiated.\n\n'
              'Use the product rule when the two functions sit side by side: '
              'f(x)·g(x). Think "x² · sin x" — differentiate each factor and add the two products.\n\n'
              'Use the chain rule when one function is inside another: '
              'f(g(x)). Think "sin(x²)" — differentiate the outside, then multiply by the '
              'derivative of the inside, which gives sin(x²)·2x.\n\n'
              'A reliable test: if you would need to add brackets around the outside '
              'function to read it, it is a chain. If the functions are simply multiplied, '
              'it is a product.',
          const Duration(hours: 3, minutes: 11),
        ),
        turn(103, 'user', 'That test actually helps. Can you show the chain rule on (3x + 2)⁴?', const Duration(hours: 2, minutes: 40)),
        turn(
          104,
          'assistant',
          'Let u = 3x + 2, so the expression is u⁴.\n\n'
              '1. Differentiate the outside: 4u³\n'
              '2. Differentiate the inside: u′ = 3\n'
              '3. Multiply: 4u³ · 3 = 12u³\n\n'
              'Substitute back: 12(3x + 2)³.\n\n'
              'The most common slip is stopping at 4u³ and forgetting to multiply by 3.',
          const Duration(hours: 2, minutes: 38),
          thinking: 'Chose the chain rule because the polynomial is raised to a power, '
              'then verified the derivative by expanding and differentiating directly.',
        ),
      ],
      2: <Map<String, dynamic>>[
        turn(201, 'user', 'Help me plan a 5-paragraph essay on why Rizal matters to the national identity.', const Duration(days: 1, hours: 4)),
        turn(
          202,
          'assistant',
          'Here is a structure that tends to hold up under a rubric:\n\n'
              '1. Introduction — the claim, and why the question is more than biography.\n'
              '2. Colonial context — what the Philippines was under Spanish rule, and the '
              'intelligence crisis that produced the Noli.\n'
              '3. The novels as argument — how Rizal used fiction to say what could not be '
              'said in a newspaper.\n'
              '4. Reception and controversy — why his work is still debated rather than settled.\n'
              '5. Conclusion — what the argument asks of the reader now.\n\n'
              'Two paragraphs of body text each, with one concrete quotation per paragraph, '
              'gets you to length without padding.',
          const Duration(days: 1, hours: 3, minutes: 55),
        ),
        turn(203, 'user', 'Good. Which quotation would be strongest for paragraph 3?', const Duration(days: 1, hours: 2)),
        turn(
          204,
          'assistant',
          'From the Noli, "Ang hindi marunong lumingon sa pinanggalingan ay hindi makararating sa paroroonan" — '
              'in English, roughly, "he who does not know how to return to where he started will not reach where he is going."\n\n'
              'It works for that paragraph because it is the line that states the argument '
              'the novel is built on, and it carries the essay\'s own logic about national '
              'identity in a single sentence. Pair it with the dedication to his mother, '
              'which makes the personal stake explicit.',
          const Duration(days: 1, hours: 1, minutes: 58),
        ),
      ],
      3: <Map<String, dynamic>>[
        turn(301, 'user', 'Why is the sky blue?', const Duration(days: 5, minutes: 20)),
        turn(
          302,
          'assistant',
          'Sunlight is white, but it arrives as a mixture of wavelengths. When it passes '
              'through the air, shorter wavelengths — blue and violet — scatter far more '
              'than longer ones. That scattering sends blue light across the sky in every '
              'direction, so it is what reaches your eyes from all over the dome.\n\n'
              'The sky is not blue at sunset for the same reason in reverse: the light '
              'travels through much more atmosphere on the way in, the blue is scattered away '
              'before it arrives, and what is left is the reds and oranges.',
          const Duration(days: 5, minutes: 18),
        ),
      ],
      4: <Map<String, dynamic>>[],
    };
  }

  double _pointsOf(List<Map<String, dynamic>> questions) {
    return questions.fold<double>(0, (double sum, Map<String, dynamic> q) {
      final Object? points = q['points'];
      return sum + (points is num ? points.toDouble() : 0);
    });
  }

  double _pointsForPart(int partId) {
    for (final Map<String, dynamic> row in <Map<String, dynamic>>[..._openExamRows(), ..._closedExamRows()]) {
      for (final Map<String, dynamic> part in _partsFor(row['id'] as int)) {
        if (part['id'] == partId) return _pointsOf(part['questions'] as List<Map<String, dynamic>>);
      }
    }
    return 1;
  }

  /// Credits one point per matching key, so a full submission scores full marks
  /// and a partial one scores in between.
  double _score(int partId, Map<int, Object?> answers, double max) {
    final Map<int, Object?>? key = _keys[partId];
    if (key == null || key.isEmpty || max <= 0) return 0;

    int correct = 0;
    for (final MapEntry<int, Object?> entry in key.entries) {
      final Object? given = answers[entry.key];
      if (given == null) continue;

      if (given is List && entry.value is List) {
        if (_sameList(given, entry.value! as List<Object?>)) correct++;
      } else if (given == entry.value) {
        correct++;
      }
    }

    return (max * correct / key.length).clamp(0, max);
  }

  static bool _sameList(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ('${a[i]}' != '${b[i]}') return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _answerArray(Map<int, Object?> answers) {
    return <Map<String, dynamic>>[
      for (final MapEntry<int, Object?> entry in answers.entries)
        <String, dynamic>{'question_number': entry.key, 'answer': entry.value},
    ];
  }

  Map<String, dynamic> _xpAward(double score, double max, {int? totalXp}) {
    final double accuracy = max <= 0 ? 0 : (score / max * 100).clamp(0, 100);
    final int completion = 50;
    final int accuracyXp = (accuracy / 5).round();
    final int onTime = 10;
    final int total = totalXp ?? completion + accuracyXp + onTime;

    return <String, dynamic>{
      'completion_xp': totalXp == null ? completion : 0,
      'accuracy_xp': totalXp == null ? accuracyXp : 0,
      'on_time_xp': totalXp == null ? onTime : 0,
      'total_xp': total,
      'accuracy_percentage': totalXp == null ? accuracy : null,
      'accuracy_pending': false,
    };
  }
}

/// A canned HTTP response: status plus a JSON body.
class FakeResponse {
  const FakeResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  factory FakeResponse.ok(Map<String, dynamic> body) => FakeResponse(200, body);

  factory FakeResponse.notFound(String message) => FakeResponse(404, <String, dynamic>{'message': message});
}