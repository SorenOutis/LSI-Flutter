import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'assignment_models.dart';

/// Design-first teacher files + grading rubric. No backend fields yet.
///
/// The API today sends no `attachments` or `rubric` keys, so these are
/// derived from what exists (`pointsPossible`, `submitted`, `isGraded`,
/// `isGroupWork`). Backend later replaces [forAssignment] with real parsing —
/// the widgets below stay the same.
class TeacherAttachment {
  const TeacherAttachment({
    required this.name,
    required this.sizeLabel,
    required this.kind,
  });

  final String name;
  final String sizeLabel;
  final AttachmentKind kind;
}

enum AttachmentKind { pdf, doc, slides, image, sheet }

extension AttachmentKindIcon on AttachmentKind {
  IconData get icon => switch (this) {
        AttachmentKind.pdf => CupertinoIcons.doc_fill,
        AttachmentKind.doc => CupertinoIcons.doc_text_fill,
        AttachmentKind.slides => CupertinoIcons.rectangle_stack_fill,
        AttachmentKind.image => CupertinoIcons.photo_fill,
        AttachmentKind.sheet => CupertinoIcons.table_fill,
      };

  String get label => switch (this) {
        AttachmentKind.pdf => 'PDF',
        AttachmentKind.doc => 'Document',
        AttachmentKind.slides => 'Slides',
        AttachmentKind.image => 'Image',
        AttachmentKind.sheet => 'Sheet',
      };
}

class RubricCriterion {
  const RubricCriterion({
    required this.title,
    required this.hint,
    required this.points,
  });

  final String title;
  final String hint;
  final int points;
}

/// Mock teacher files: every assignment gets the brief; group work adds the
/// team sheet; graded work keeps the annotated brief.
List<TeacherAttachment> teacherFilesFor(AssignmentItem a) {
  final List<TeacherAttachment> files = <TeacherAttachment>[
    TeacherAttachment(
      name: '${a.title}.pdf',
      sizeLabel: '${(a.pointsPossible % 4) + 1}.${(a.id % 9)} MB · PDF · brief',
      kind: AttachmentKind.pdf,
    ),
  ];
  if (a.isGroupWork) {
    files.add(const TeacherAttachment(
      name: 'team-roles.docx',
      sizeLabel: '96 KB · DOCX · who does what',
      kind: AttachmentKind.doc,
    ));
  }
  if (a.title.toLowerCase().contains('limit') || a.title.toLowerCase().contains('lab')) {
    files.add(const TeacherAttachment(
      name: 'reference-figure.png',
      sizeLabel: '1.1 MB · PNG · diagram',
      kind: AttachmentKind.image,
    ));
  }
  return files;
}

/// Mock rubric split across the assignment's points. Sums to pointsPossible.
List<RubricCriterion> rubricFor(AssignmentItem a) {
  final int total = a.pointsPossible > 0 ? a.pointsPossible : 20;
  final int correctness = (total * 0.5).round();
  final int method = (total * 0.3).round();
  final int presentation = total - correctness - method;
  return <RubricCriterion>[
    RubricCriterion(title: 'Correctness', hint: 'Right answers, right units', points: correctness),
    RubricCriterion(title: 'Method shown', hint: 'Steps a classmate could follow', points: method),
    RubricCriterion(title: 'Presentation', hint: 'Neat, labelled, on time', points: presentation.clamp(0, total)),
  ];
}

/// Mock submitted file for the Your-work card.
TeacherAttachment submittedFileFor(AssignmentItem a) {
  return TeacherAttachment(
    name: a.isGraded ? 'submission-graded.pdf' : 'submission.pdf',
    sizeLabel: a.isGraded ? '1.4 MB · PDF · annotated' : '1.2 MB · PDF · awaiting grade',
    kind: AttachmentKind.pdf,
  );
}
