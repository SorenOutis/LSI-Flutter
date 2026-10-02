import 'package:intl/intl.dart';

import '../../../core/utils/json_parsing.dart';

/// One assignment row, flattened from the `/assignments` payload.
///
/// The endpoint nests the student's own submission under `submission` (null
/// when nothing was handed in) and group work under `group`; both are folded
/// into flat fields here so the UI never has to null-walk three levels.
class AssignmentItem {
  const AssignmentItem({
    required this.id,
    required this.title,
    this.description,
    this.dueAt,
    required this.pointsPossible,
    required this.groupMin,
    required this.groupMax,
    this.courseName,
    required this.submitted,
    required this.submissionStatus,
    this.grade,
    required this.points,
    required this.xpEarned,
    this.feedback,
    required this.hasUnseenFeedback,
    required this.memberCount,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final int pointsPossible;

  /// Group size the assignment allows. `max > 1` means it is group work.
  final int groupMin;
  final int groupMax;

  final String? courseName;

  final bool submitted;

  /// Wire value of the submission's status ("Pending", "Graded", …).
  final String submissionStatus;
  final String? grade;
  final double points;
  final double xpEarned;
  final String? feedback;

  /// Feedback posted after the student last opened it — worth a badge.
  final bool hasUnseenFeedback;

  /// Group members so far, including the student themselves.
  final int memberCount;

  bool get isGroupWork => groupMax > 1;

  bool get isOverdue => !submitted && (dueAt?.isBefore(DateTime.now()) ?? false);

  bool get isGraded => submitted && (grade != null || submissionStatus.toLowerCase() == 'graded');

  /// Under two days left and not handed in.
  bool get isDueSoon {
    final DateTime? due = dueAt;
    if (submitted || due == null || isOverdue) return false;
    return due.difference(DateTime.now()).inHours <= 48;
  }

  int get daysRemaining {
    final DateTime? due = dueAt;
    if (due == null) return 0;
    return due.difference(DateTime.now()).inDays;
  }

  /// Short, human phrasing for the deadline. An assignment with no due date is
  /// valid — the API sends null rather than a sentinel.
  String get dueLabel {
    final DateTime? due = dueAt;
    if (due == null) return 'No deadline';

    final DateTime today = DateTime.now();
    final int dayGap = DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    if (dayGap < 0) {
      final int late = dayGap.abs();
      return late == 1 ? 'Due yesterday' : 'Due $late days ago';
    }
    if (dayGap == 0) return 'Due today, ${DateFormat.jm().format(due)}';
    if (dayGap == 1) return 'Due tomorrow';
    return 'Due in $dayGap days';
  }

  String get dueAtLabel => dueAt == null ? 'No deadline' : DateFormat.MMMd().add_jm().format(dueAt!);

  factory AssignmentItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> submission = json.asMap('submission');
    final Map<String, dynamic> groupRules = json.asMap('group_rules');
    final Map<String, dynamic> course = json.asMap('course');
    final Map<String, dynamic> group = json.asMap('group');

    return AssignmentItem(
      id: json.asInt('id'),
      title: json.asString('title'),
      description: json.asStringOrNull('description'),
      // `due_date` is the client-facing ISO string (dueDateForClient), so it is
      // read as a local wall-clock time rather than converted from UTC.
      dueAt: json.asDateOrNull('due_date')?.toLocal(),
      pointsPossible: json.asInt('points_possible'),
      groupMin: groupRules.asInt('min', fallback: 1),
      groupMax: groupRules.asInt('max', fallback: 1),
      courseName: course.asStringOrNull('name'),
      submitted: submission.asBool('submitted'),
      submissionStatus: submission.asString('status', fallback: 'Pending'),
      grade: submission.asStringOrNull('grade'),
      points: submission.asDouble('points'),
      xpEarned: submission.asDouble('xp_earned'),
      feedback: submission.asStringOrNull('feedback'),
      hasUnseenFeedback: submission.asBool('has_unseen_feedback'),
      memberCount: group.asMapList('members').length,
    );
  }
}

class AssignmentsData {
  const AssignmentsData({required this.assignments});

  final List<AssignmentItem> assignments;

  bool get isEmpty => assignments.isEmpty;

  List<AssignmentItem> get outstanding {
    final List<AssignmentItem> open = assignments
        .where((AssignmentItem a) => !a.submitted)
        .toList(growable: false);
    return open..sort((AssignmentItem a, AssignmentItem b) {
      // No deadline sorts last: it is never urgent.
      final DateTime aDue = a.dueAt ?? DateTime(2999);
      final DateTime bDue = b.dueAt ?? DateTime(2999);
      return aDue.compareTo(bDue);
    });
  }

  List<AssignmentItem> get completed =>
      assignments.where((AssignmentItem a) => a.submitted).toList(growable: false);

  int get overdueCount => assignments.where((AssignmentItem a) => a.isOverdue).length;

  factory AssignmentsData.fromJson(Map<String, dynamic> json) {
    return AssignmentsData(
      assignments: json.asMapList('assignments').map(AssignmentItem.fromJson).toList(growable: false),
    );
  }
}
