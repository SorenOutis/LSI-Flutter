import '../../../core/utils/json_parsing.dart';

/// Mirrors `App\Enums\QuestionType`.
enum QuestionType {
  multipleChoice('multiple_choice', 'Multiple Choice'),
  identification('identification', 'Identification'),
  enumeration('enumeration', 'Enumeration'),
  matching('matching', 'Matching Type'),
  trueFalse('true_false', 'True/False'),
  essay('essay', 'Essay');

  const QuestionType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static QuestionType fromWire(String? value) {
    return QuestionType.values.firstWhere(
      (QuestionType type) => type.wireValue == value,
      orElse: () => QuestionType.multipleChoice,
    );
  }
}

class QuestionOption {
  const QuestionOption({required this.text, required this.isCorrect, this.hasKey = false});

  final String text;

  /// Null until the exam closes and answers are revealed — the server omits the
  /// key entirely rather than sending `false`, so a null here means "not yet
  /// revealed", not "wrong".
  final bool? isCorrect;
  final bool hasKey;

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      text: json.asString('text'),
      isCorrect: json.containsKey('is_correct') ? json.asBool('is_correct') : null,
      hasKey: json.containsKey('is_correct'),
    );
  }
}

class MatchingItem {
  const MatchingItem({required this.index, required this.prompt, required this.points});

  final int index;
  final String prompt;
  final double points;

  factory MatchingItem.fromJson(Map<String, dynamic> json) {
    return MatchingItem(
      index: json.asInt('index'),
      prompt: json.asString('prompt'),
      points: json.asDouble('points', fallback: 1),
    );
  }
}

class MatchingOption {
  const MatchingOption({required this.value, required this.text});

  final String value;
  final String text;

  factory MatchingOption.fromJson(Map<String, dynamic> json) {
    return MatchingOption(value: json.asString('value'), text: json.asString('text'));
  }
}

/// A single question inside an exam part.
///
/// The API sends `points` as a number for plain questions and as a *precomputed
/// sum* for enumeration and matching questions, so `points` is always a double
/// here.
class ExamQuestion {
  const ExamQuestion({
    required this.index,
    required this.text,
    required this.type,
    required this.points,
    required this.options,
    required this.enumerationPoints,
    required this.matchingItems,
    required this.matchingOptions,
    required this.revealedCorrectAnswer,
  });

  /// 1-based, matching the `question_number` the save/submit endpoints expect.
  final int index;
  final String text;
  final QuestionType type;
  final double points;
  final List<QuestionOption> options;
  final List<double> enumerationPoints;
  final List<MatchingItem> matchingItems;
  final List<MatchingOption> matchingOptions;
  final Object? revealedCorrectAnswer;

  factory ExamQuestion.fromJson(Map<String, dynamic> json, int index) {
    return ExamQuestion(
      index: index + 1,
      text: json.asString('text'),
      type: QuestionType.fromWire(json.asStringOrNull('type')),
      points: json.asDoubleOrNull('points') ?? 0,
      options: json.asMapList('options').map(QuestionOption.fromJson).toList(growable: false),
      enumerationPoints: json
          .asMapList('enumeration_items')
          .map((Map<String, dynamic> item) => item.asDouble('points', fallback: 1))
          .toList(growable: false),
      matchingItems: json.asMapList('matching_items').map(MatchingItem.fromJson).toList(growable: false),
      matchingOptions: json.asMapList('matching_options').map(MatchingOption.fromJson).toList(growable: false),
      revealedCorrectAnswer: json['correct_answer'],
    );
  }
}

class ExamPart {
  const ExamPart({
    required this.id,
    required this.examId,
    required this.title,
    required this.instructions,
    required this.points,
    required this.questions,
  });

  final int id;
  final int examId;
  final String? title;
  final String? instructions;
  final double points;
  final List<ExamQuestion> questions;

  factory ExamPart.fromJson(Map<String, dynamic> json) {
    final List<Map<String, dynamic>> rawQuestions = json.asMapList('questions');
    return ExamPart(
      id: json.asInt('id'),
      examId: json.asInt('exam_id'),
      title: json.asStringOrNull('title'),
      instructions: json.asStringOrNull('instructions'),
      points: json.asDouble('points'),
      questions: [
        for (int i = 0; i < rawQuestions.length; i++) ExamQuestion.fromJson(rawQuestions[i], i),
      ],
    );
  }
}

/// A saved-but-unsubmitted answer draft for one part.
class AnswerDraft {
  const AnswerDraft({required this.answers, required this.savedAt});

  /// Raw values keyed by 1-based question number. The value's shape depends on
  /// the question type: an int index, a String, or a `List` of Strings.
  final Map<int, Object?> answers;
  final DateTime? savedAt;

  factory AnswerDraft.fromJson(Map<String, dynamic> json) {
    return AnswerDraft(
      answers: parseDraftAnswers(json.asMapList('answers')),
      savedAt: parseFlexibleDate(json['saved_at']),
    );
  }

  static AnswerDraft empty() => const AnswerDraft(answers: {}, savedAt: null);
}

/// Convert the `[{question_number, answer}]` array into a lookup.
///
/// Built defensively: the draft is stored as a JSON blob in the database and
/// must never be able to crash a student's session on resume.
Map<int, Object?> parseDraftAnswers(List<Map<String, dynamic>> raw) {
  final Map<int, Object?> answers = <int, Object?>{};
  for (final Map<String, dynamic> item in raw) {
    final Object? number = item['question_number'];
    if (number is! num) continue;
    answers[number.toInt()] = item['answer'];
  }
  return answers;
}

/// One student's submission for one part.
class ExamSubmission {
  const ExamSubmission({
    required this.id,
    required this.examPartId,
    required this.status,
    required this.score,
    required this.isLate,
    required this.gradingFailed,
    required this.answers,
  });

  final int id;
  final int examPartId;
  final String status;

  /// A JSON *string* here ("12.50") because of the `decimal:2` cast, unlike the
  /// real number returned by the part-status endpoint.
  final String score;
  final bool isLate;
  final bool gradingFailed;
  final Map<int, Object?> answers;

  bool get isPendingGrading => status == 'pending_ai' || status == 'pending_review';

  factory ExamSubmission.fromJson(Map<String, dynamic> json) {
    return ExamSubmission(
      id: json.asInt('id'),
      examPartId: json.asInt('exam_part_id'),
      status: json.asString('status'),
      score: json.asString('score'),
      isLate: json.asBool('is_late'),
      gradingFailed: json.asBool('grading_failed'),
      answers: parseDraftAnswers(json.asMapList('answers')),
    );
  }
}

class ExamXpAward {
  const ExamXpAward({
    required this.completionXp,
    required this.accuracyXp,
    required this.onTimeXp,
    required this.totalXp,
    required this.accuracyPercentage,
    required this.accuracyPending,
  });

  final int completionXp;
  final int accuracyXp;
  final int onTimeXp;
  final int totalXp;
  final double? accuracyPercentage;
  final bool accuracyPending;

  bool get isEmpty => totalXp == 0 && completionXp == 0 && accuracyXp == 0 && onTimeXp == 0;

  factory ExamXpAward.fromJson(Map<String, dynamic> json) {
    return ExamXpAward(
      completionXp: json.asInt('completion_xp'),
      accuracyXp: json.asInt('accuracy_xp'),
      onTimeXp: json.asInt('on_time_xp'),
      totalXp: json.asInt('total_xp'),
      accuracyPercentage: json.asDoubleOrNull('accuracy_percentage'),
      accuracyPending: json.asBool('accuracy_pending'),
    );
  }
}

/// The full exam payload from `GET /api/exams/{exam}`.
class ExamDetail {
  const ExamDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.parts,
    required this.setTitle,
    required this.startsAt,
    required this.endsAt,
    required this.isOpenNow,
    required this.isUpcoming,
    required this.hasEnded,
    required this.sectionName,
    required this.durationMinutes,
    required this.submissions,
    required this.partDeadlines,
    required this.answerDrafts,
    required this.xpAward,
  });

  final int id;
  final String title;
  final String? description;
  final List<ExamPart> parts;
  final String? setTitle;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isOpenNow;
  final bool isUpcoming;
  final bool hasEnded;
  final String? sectionName;
  final int durationMinutes;

  /// Submissions keyed by part id.
  final Map<int, ExamSubmission> submissions;

  /// Authoritative per-part deadlines keyed by part id. A student resumes the
  /// countdown from these instead of resetting it on reload.
  final Map<int, DateTime> partDeadlines;
  final Map<int, AnswerDraft> answerDrafts;
  final ExamXpAward? xpAward;

  bool isPartSubmitted(int partId) => submissions.containsKey(partId);

  int get submittedCount => submissions.length;

  int get totalParts => parts.length;

  bool get isFullySubmitted => parts.isNotEmpty && submittedCount >= parts.length;

  DateTime? deadlineFor(int partId) => partDeadlines[partId];

  factory ExamDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> exam = json.asMap('exam');
    final Map<String, dynamic> set = exam.asMap('set');

    return ExamDetail(
      id: exam.asInt('id'),
      title: exam.asString('title'),
      description: exam.asStringOrNull('description'),
      parts: exam.asMapList('parts').map(ExamPart.fromJson).toList(growable: false),
      setTitle: set['title'] as String?,
      startsAt: parseFlexibleDate(exam['starts_at_iso'])?.toLocal(),
      endsAt: parseFlexibleDate(exam['ends_at_iso'])?.toLocal(),
      isOpenNow: exam.asBool('is_open_now'),
      isUpcoming: exam.asBool('is_upcoming'),
      hasEnded: exam.asBool('has_ended'),
      sectionName: exam.asStringOrNull('section_name'),
      durationMinutes: exam.asInt('duration_minutes'),
      submissions: {
        for (final MapEntry<String, dynamic> entry in json.asIdKeyedMap('submissions').entries)
          if (int.tryParse(entry.key) case final int id) id: ExamSubmission.fromJson(entry.value),
      },
      partDeadlines: {
        for (final MapEntry<String, dynamic> entry in json.asIdKeyedMap('partDeadlines').entries)
          if (int.tryParse(entry.key) case final int id)
            if (parseFlexibleDate(entry.value['value'] ?? entry.value) case final DateTime deadline)
              id: deadline.toLocal(),
      },
      answerDrafts: {
        for (final MapEntry<String, dynamic> entry in json.asIdKeyedMap('answerDrafts').entries)
          if (int.tryParse(entry.key) case final int id) id: AnswerDraft.fromJson(entry.value),
      },
      xpAward: json['xpAward'] == null ? null : ExamXpAward.fromJson(json.asMap('xpAward')),
    );
  }
}

/// A compact exam card from `GET /api/exams`.
///
/// Cards carry part metadata but no questions (`ExamPartSerializer::many(..., false, false)`),
/// so opening a card is what costs an extra request.
class ExamCard {
  const ExamCard({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.isOpenNow,
    required this.isUpcoming,
    required this.hasEnded,
    required this.isLocked,
    required this.durationMinutes,
    required this.partsCount,
    required this.submittedParts,
    required this.submissions,
    required this.setTitle,
    required this.resultsAvailable,
    required this.sectionName,
    required this.seasonName,
    required this.examDate,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isOpenNow;
  final bool isUpcoming;
  final bool hasEnded;

  /// True once every part is submitted *or* the exam is closed — either way the
  /// card cannot be started.
  final bool isLocked;
  final int durationMinutes;
  final int partsCount;
  final int submittedParts;
  final List<ExamSubmission> submissions;
  final String? setTitle;

  /// The student took part AND the exam is closed. `isLocked` alone is not
  /// enough — finishing every part is not the same as results being released.
  final bool resultsAvailable;
  final String? sectionName;
  final String? seasonName;
  final DateTime? examDate;

  bool get isCompleted => partsCount > 0 && submittedParts >= partsCount;

  bool get isStartable => isOpenNow && !isLocked;

  factory ExamCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> set = json.asMap('set');

    return ExamCard(
      id: json.asInt('id'),
      title: json.asString('title'),
      description: json.asStringOrNull('description'),
      startsAt: parseFlexibleDate(json['starts_at_iso'])?.toLocal(),
      endsAt: parseFlexibleDate(json['ends_at_iso'])?.toLocal(),
      isOpenNow: json.asBool('is_open_now'),
      isUpcoming: json.asBool('is_upcoming'),
      hasEnded: json.asBool('has_ended'),
      isLocked: json.asBool('is_locked'),
      durationMinutes: json.asInt('duration_minutes'),
      partsCount: json.asInt('total_parts'),
      submittedParts: json.asInt('submitted_parts_count'),
      submissions: json.asMapList('submissions').map(ExamSubmission.fromJson).toList(growable: false),
      setTitle: set['title'] as String?,
      resultsAvailable: json.asBool('results_available'),
      sectionName: json.asStringOrNull('section_name'),
      seasonName: json.asStringOrNull('season_name'),
      examDate: parseFlexibleDate(json['exam_date_iso']),
    );
  }
}

/// Exams grouped by season — the shape `GET /api/exams` returns.
class ExamSeasonGroup {
  const ExamSeasonGroup({required this.seasonName, required this.exams});

  final String seasonName;
  final List<ExamCard> exams;

  factory ExamSeasonGroup.fromJson(Map<String, dynamic> json) {
    return ExamSeasonGroup(
      seasonName: json.asString('seasonName', fallback: 'Other'),
      exams: json.asMapList('exams').map(ExamCard.fromJson).toList(growable: false),
    );
  }
}

/// The result of `POST /api/exams/{exam}/parts/{part}/submit`.
class SubmitPartResult {
  const SubmitPartResult({
    required this.submissionId,
    required this.examPartId,
    required this.status,
    required this.score,
    required this.isLate,
    required this.awaitingTeacherReview,
    required this.xpAward,
  });

  final int submissionId;
  final int examPartId;
  final String status;
  final double score;
  final bool isLate;
  final bool awaitingTeacherReview;
  final ExamXpAward? xpAward;

  bool get isPendingGrading => status == 'pending_ai' || status == 'pending_review';

  factory SubmitPartResult.fromJson(Map<String, dynamic> json) {
    return SubmitPartResult(
      submissionId: json.asInt('submission_id'),
      examPartId: json.asInt('exam_part_id'),
      status: json.asString('status'),
      score: json.asDoubleOrNull('score') ?? 0,
      isLate: json.asBool('is_late'),
      awaitingTeacherReview: json.asBool('awaiting_teacher_review'),
      xpAward: json['xp_award'] == null ? null : ExamXpAward.fromJson(json.asMap('xp_award')),
    );
  }
}

/// Polled while a part waits for AI or teacher grading.
class ExamPartStatus {
  const ExamPartStatus({
    required this.status,
    required this.scored,
    required this.score,
    required this.isLate,
    required this.gradingFailed,
    required this.awaitingTeacherReview,
    required this.xpAward,
  });

  final String status;
  final bool scored;
  final double? score;
  final bool isLate;
  final bool gradingFailed;
  final bool awaitingTeacherReview;
  final ExamXpAward? xpAward;

  static const ExamPartStatus notSubmitted = ExamPartStatus(
    status: 'not_submitted',
    scored: false,
    score: null,
    isLate: false,
    gradingFailed: false,
    awaitingTeacherReview: false,
    xpAward: null,
  );

  bool get isPending => status == 'pending_ai' || status == 'pending_review';

  /// True once polling can stop: either the score is in, a teacher must act, or
  /// grading gave up.
  bool get isSettled => !isPending || awaitingTeacherReview || gradingFailed;

  factory ExamPartStatus.fromJson(Map<String, dynamic> json) {
    final String status = json.asString('status');
    if (status == 'not_submitted') return notSubmitted;

    return ExamPartStatus(
      status: status,
      scored: json.asBool('scored'),
      score: json.asDoubleOrNull('score'),
      isLate: json.asBool('is_late'),
      gradingFailed: json.asBool('grading_failed'),
      awaitingTeacherReview: json.asBool('awaiting_teacher_review'),
      xpAward: json['xp_award'] == null ? null : ExamXpAward.fromJson(json.asMap('xp_award')),
    );
  }
}

/// The clock returned by `POST /api/exams/{exam}/parts/{part}/start`.
class PartClock {
  const PartClock({required this.startedAt, required this.deadline});

  final DateTime? startedAt;

  /// Authoritative end of the part, already including the grace window. Null
  /// when the part has no `duration_minutes`.
  final DateTime? deadline;

  factory PartClock.fromJson(Map<String, dynamic> json) {
    return PartClock(
      startedAt: parseFlexibleDate(json['started_at'])?.toLocal(),
      deadline: parseFlexibleDate(json['deadline'])?.toLocal(),
    );
  }
}