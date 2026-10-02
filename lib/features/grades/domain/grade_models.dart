import '../../../core/utils/json_parsing.dart';

/// One graded period for a subject — a prelim, midterm, quarter and so on.
///
/// `score` and `maxScore` stay strings because the API emits them through
/// `number_format()`, so "88.00" must render as written rather than round-trip
/// through a double.
class PeriodGrade {
  const PeriodGrade({
    required this.key,
    required this.label,
    this.group,
    required this.score,
    required this.maxScore,
    required this.percentage,
    this.remarks,
    this.updatedAt,
  });

  final String key;
  final String label;

  /// The semester a quarter belongs to. Only set for senior-high subjects,
  /// whose grades are reported per semester rather than per period.
  final String? group;

  final String score;
  final String maxScore;

  /// 0–100, already computed server-side.
  final double percentage;

  final String? remarks;
  final String? updatedAt;

  bool get isGraded => score.isNotEmpty;

  String get scoreLabel => '$score / $maxScore';

  /// Builds from a `{key, label, grade}` row.
  ///
  /// `grade` is null for a period that has not been marked yet, and the period
  /// still belongs in the list: dropping it would turn a half-graded subject
  /// into one that looks finished, and hide which periods are still to come.
  factory PeriodGrade.fromRow(Map<String, dynamic> row, {String? group}) {
    final Map<String, dynamic> grade = row['grade'] is Map<String, dynamic>
        ? row['grade'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return PeriodGrade(
      key: row.asString('key'),
      label: row.asString('label'),
      group: group,
      score: grade.asString('score'),
      maxScore: grade.asString('maxScore'),
      percentage: grade.asDouble('percentage'),
      remarks: grade.asStringOrNull('remarks'),
      updatedAt: grade.asStringOrNull('updatedAt'),
    );
  }
}

/// A subject the student is enrolled in.
///
/// Derived counts are computed from [periods] rather than trusting
/// `gradedPeriods`/`totalPeriods` from the payload: for senior-high subjects the
/// server reports those as 0 because it only counts per-period grades, which
/// would render "0 of 0 graded" above four visible quarters.
class SubjectGrade {
  const SubjectGrade({
    required this.subject,
    required this.sectionName,
    required this.schoolLevelLabel,
    required this.periods,
    this.currentAverage,
    this.semesterGrade,
  });

  final String subject;
  final String sectionName;
  final String schoolLevelLabel;
  final List<PeriodGrade> periods;

  /// Provisional: averages only the periods graded so far.
  final double? currentAverage;

  /// Official, and only present once every required period has a grade.
  final double? semesterGrade;

  int get gradedCount => periods.where((PeriodGrade p) => p.isGraded).length;

  int get periodCount => periods.length;

  bool get isComplete => periodCount > 0 && gradedCount == periodCount;

  /// What to show as the subject's number: the official grade when it exists,
  /// otherwise the provisional average.
  double? get standing {
    if (semesterGrade != null) return semesterGrade;
    if (currentAverage != null) return currentAverage;

    final List<double> graded = periods
        .where((PeriodGrade p) => p.isGraded)
        .map((PeriodGrade p) => p.percentage)
        .toList(growable: false);
    if (graded.isEmpty) return null;

    return graded.reduce((double a, double b) => a + b) / graded.length;
  }

  factory SubjectGrade.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> section = json.asMap('section');

    List<PeriodGrade> periods = <PeriodGrade>[
      for (final Map<String, dynamic> row in json.asMapList('periodGrades')) PeriodGrade.fromRow(row),
    ];

    // Senior high reports whole semesters with quarters inside them instead.
    if (periods.isEmpty) {
      periods = <PeriodGrade>[
        for (final Map<String, dynamic> semester in json.asMapList('semesterGrades'))
          for (final Map<String, dynamic> quarter in semester.asMapList('quarters'))
            PeriodGrade.fromRow(quarter, group: semester.asString('label')),
      ];
    }

    return SubjectGrade(
      subject: json.asString('subject'),
      sectionName: section.asString('name'),
      schoolLevelLabel: section.asString('schoolLevelLabel', fallback: 'College'),
      periods: periods,
      currentAverage: json.asDoubleOrNull('currentAverage'),
      semesterGrade: json.asDoubleOrNull('semesterGrade'),
    );
  }
}

/// Everything `/api/v1/grades` returns in one payload.
class GradesData {
  const GradesData({required this.subjects});

  final List<SubjectGrade> subjects;

  bool get isEmpty => subjects.isEmpty;

  /// Mean of every subject's standing, ignoring subjects with no grade yet.
  double? get overallAverage {
    final List<double> standings = subjects
        .map((SubjectGrade s) => s.standing)
        .whereType<double>()
        .toList(growable: false);
    if (standings.isEmpty) return null;

    return standings.reduce((double a, double b) => a + b) / standings.length;
  }

  int get completedSubjects => subjects.where((SubjectGrade s) => s.isComplete).length;

  factory GradesData.fromJson(Map<String, dynamic> json) {
    return GradesData(
      subjects: json.asMapList('subjectGrades').map(SubjectGrade.fromJson).toList(growable: false),
    );
  }
}
