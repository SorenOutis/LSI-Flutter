import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parsing.dart';
import '../domain/exam_models.dart';

class ExamPage {
  const ExamPage({required this.groups, required this.hasMore, required this.nextCursor});

  final List<ExamSeasonGroup> groups;
  final bool hasMore;

  /// Opaque Laravel cursor. Null on the last page.
  final String? nextCursor;
}

class ExamRepository {
  ExamRepository(this._client);

  final ApiClient _client;

  /// Cursor-paginated in pages of 24. Pass [cursor] to walk forward.
  Future<ExamPage> listExams({String? cursor}) async {
    final Map<String, dynamic> json = await _client.getJson(
      '/exams',
      query: cursor == null ? null : {'cursor': cursor},
    );

    final Map<String, dynamic> meta = json.asMap('meta');

    return ExamPage(
      groups: json.asMapList('data').map(ExamSeasonGroup.fromJson).toList(growable: false),
      hasMore: meta.asBool('hasMore'),
      nextCursor: meta.asStringOrNull('nextCursor'),
    );
  }

  /// Full exam with the assigned set's parts and questions.
  ///
  /// This call is what deals the student their set, and the deal is sticky —
  /// reloading always returns the same set, so it is safe to call on resume.
  Future<ExamDetail> fetchDetail(int examId) async {
    return ExamDetail.fromJson(await _client.getJson('/exams/$examId'));
  }

  /// Start or resume the server clock for a part.
  ///
  /// `started_at` is written once and never reset, so calling this repeatedly
  /// cannot be used to buy extra time; only the returned deadline matters.
  Future<PartClock> startPart({required int examId, required int partId}) async {
    final Map<String, dynamic> json = await _client.postJson('/exams/$examId/parts/$partId/start');
    return PartClock.fromJson(json);
  }

  /// Persist changed answers. Only [changed] is sent, keyed by question number.
  Future<int> saveAnswers({
    required int examId,
    required int partId,
    required Map<int, Object?> changed,
  }) async {
    if (changed.isEmpty) return 0;

    final Map<String, dynamic> json = await _client.putJson(
      '/exams/$examId/parts/$partId/answers',
      body: {
        'answers': [
          for (final MapEntry<int, Object?> entry in changed.entries)
            {'question_number': entry.key, 'answer': entry.value},
        ],
      },
    );

    return json.asInt('answered_count');
  }

  /// Submit a part. Answers already persisted via [saveAnswers] are safe; pass
  /// the current in-memory map to be sure the submission reflects the screen.
  Future<SubmitPartResult> submitPart({
    required int examId,
    required int partId,
    required Map<int, Object?> answers,
  }) async {
    final Map<String, dynamic> json = await _client.postJson(
      '/exams/$examId/parts/$partId/submit',
      body: {
        'answers': [
          for (final MapEntry<int, Object?> entry in answers.entries)
            if (entry.value != null) {'question_number': entry.key, 'answer': entry.value},
        ],
      },
    );

    return SubmitPartResult.fromJson(json);
  }

  /// Poll while essays are being graded.
  Future<ExamPartStatus> partStatus({required int examId, required int partId}) async {
    final Map<String, dynamic> json = await _client.getJson('/exams/$examId/parts/$partId/status');
    return ExamPartStatus.fromJson(json);
  }

  /// Results with answers, unlocked once the exam is closed.
  Future<({List<ExamSubmission> submissions, String examTitle})> review(int examId) async {
    final Map<String, dynamic> json = await _client.getJson('/exams/$examId/review');
    return (
      submissions: json.asMapList('submissions').map(ExamSubmission.fromJson).toList(growable: false),
      examTitle: json.asMap('exam').asString('title'),
    );
  }
}