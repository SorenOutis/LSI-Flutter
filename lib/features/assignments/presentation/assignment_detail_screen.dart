import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/lsi_mascot.dart';
import '../domain/assignment_extras.dart';
import '../domain/assignment_models.dart';
import '../state/assignment_providers.dart';
import 'sheets/attachment_viewer_sheet.dart';
import 'sheets/submit_assignment_sheet.dart';

/// Finds one assignment from the already-fetched list (no new endpoint yet).
///
/// Backend later: `GET /assignments/:id` with `submission`, `group`,
/// `attachments`, `rubric`. UI stays the same.
final assignmentDetailProvider =
    FutureProvider.family<AssignmentItem?, int>((Ref ref, int id) async {
  final AssignmentsData data = await ref.watch(assignmentsProvider.future);
  for (final AssignmentItem a in data.assignments) {
    if (a.id == id) return a;
  }
  return null;
});

/// Detail flow: header -> instructions -> group -> submission/grade ->
/// sticky [Submit assignment] button. Tapping it opens
/// [showSubmitAssignmentSheet].
class AssignmentDetailScreen extends ConsumerWidget {
  const AssignmentDetailScreen({super.key, required this.assignmentId});

  final int assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AssignmentItem?> detail = ref.watch(assignmentDetailProvider(assignmentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
      ),
      body: detail.when(
        loading: () => const SkeletonList(count: 3),
        error: (Object e, StackTrace _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(assignmentDetailProvider(assignmentId))),
        data: (AssignmentItem? a) {
          if (a == null) {
            return const EmptyView(title: 'Not found', message: 'This assignment is no longer in your list.', icon: CupertinoIcons.doc_plaintext);
          }
          return _DetailBody(assignment: a);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.assignment});
  final AssignmentItem assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AssignmentItem a = assignment;

    final ({Color color, IconData icon, String label}) status = switch (a) {
      _ when a.isGraded => (color: context.accents.success, icon: CupertinoIcons.checkmark_circle_fill, label: a.grade ?? 'Graded'),
      _ when a.submitted => (color: context.accents.warning, icon: CupertinoIcons.hourglass, label: a.submissionStatus),
      _ when a.isOverdue => (color: scheme.error, icon: CupertinoIcons.exclamationmark_circle_fill, label: 'Overdue'),
      _ when a.isDueSoon => (color: context.accents.warning, icon: CupertinoIcons.clock_fill, label: 'Due soon'),
      _ => (color: scheme.primary, icon: CupertinoIcons.doc_plaintext, label: 'Open'),
    };

    final bool canSubmit = !a.isGraded; // Design rule: graded locks resubmit.

    return Stack(
      children: <Widget>[
        ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(a.title, style: theme.textTheme.titleLarge),
                                const SizedBox(height: 4),
                                Text('${a.courseName ?? 'General'} · ${a.pointsPossible} pts', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 8),
                                StatusChip(label: status.label, color: status.color, icon: status.icon, dense: true),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          LsiMascot(mood: a.isGraded ? LsiMascotMood.celebrating : a.isOverdue ? LsiMascotMood.worried : LsiMascotMood.studying, size: 56),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: (a.isOverdue ? scheme.error : scheme.primary).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: <Widget>[
                            Icon(CupertinoIcons.calendar, size: 18, color: a.isOverdue ? scheme.error : scheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(a.dueAtLabel, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  Text(a.dueLabel, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (a.description != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text('Instructions', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(a.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (a.isGroupWork) ...<Widget>[
              const SectionHeader(title: 'Group work', subtitle: 'Up to ${4} per team'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: <Widget>[
                        Row(children: <Widget>[Icon(CupertinoIcons.person_2_fill, size: 18, color: scheme.primary), const SizedBox(width: 8), Expanded(child: Text(a.memberCount > 0 ? '${a.memberCount} joined · min ${a.groupMin}, max ${a.groupMax}' : 'Form a group of ${a.groupMin}–${a.groupMax}', style: theme.textTheme.bodyMedium))]),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => AppSheet.show<void>(context: context, title: 'Group invite', subtitle: 'Design preview', icon: CupertinoIcons.person_2, children: const <Widget>[SheetNote(message: 'Backend later: POST /assignments/:id/groups + invites. Design shows member list, invite link, pending invites.')]),
                          icon: const Icon(CupertinoIcons.person_badge_plus, size: 16),
                          label: const Text('Manage group'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SectionHeader(title: 'Your work', subtitle: 'File, grade and feedback land here'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SubmissionCard(assignment: a),
            ),
            const SectionHeader(title: 'Files from your teacher', subtitle: 'Brief + references · tap to preview'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TeacherFiles(assignment: a),
            ),
            const SectionHeader(title: 'How you will be graded', subtitle: 'Rubric adds up to total points'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RubricCard(assignment: a),
            ),
            if (a.feedback != null) ...<Widget>[
              const SectionHeader(title: 'Feedback'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (a.hasUnseenFeedback)
                          Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusChip(label: 'New feedback', color: context.accents.xp, dense: true)),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Icon(CupertinoIcons.chat_bubble_text_fill, size: 18, color: scheme.primary), const SizedBox(width: 8), Expanded(child: Text(a.feedback!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)))]),
                        if (a.isGraded) ...<Widget>[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(children: <Widget>[Expanded(child: Text('Points', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))), Text('${a.points.round()} / ${a.pointsPossible}', style: theme.textTheme.titleSmall)]),
                          Row(children: <Widget>[Expanded(child: Text('XP earned', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))), Text('+${a.xpEarned.round()} XP', style: theme.textTheme.titleSmall?.copyWith(color: context.accents.xp))]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SectionHeader(title: 'How grading works', subtitle: 'So the wait makes sense'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: MascotMessage(mood: LsiMascotMood.happy, title: 'Graded by your teacher', subtitle: 'XP + points land together when graded. Late work may earn less — submit early when you can.'),
                ),
              ),
            ),
          ],
        ),
        // Sticky action bar.
        Positioned(
          left: 16, right: 16, bottom: 16,
          child: SafeArea(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: canSubmit
                  ? () => showSubmitAssignmentSheet(context, ref, a)
                  : () => showSnack(context, 'Already graded — resubmit is locked (design).'),
              icon: Icon(canSubmit ? CupertinoIcons.paperplane_fill : CupertinoIcons.lock_fill, size: 18),
              label: Text(canSubmit ? (a.submitted ? 'Resubmit assignment' : 'Submit assignment') : 'Graded · locked'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.assignment});
  final AssignmentItem assignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AssignmentItem a = assignment;

    if (!a.submitted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MascotMessage(
            mood: a.isOverdue ? LsiMascotMood.worried : LsiMascotMood.studying,
            title: a.isOverdue ? 'Past the deadline — still submittable' : 'Nothing handed in yet',
            subtitle: 'Tap Submit below, pick a file, add a note. Takes ~30 seconds.',
          ),
        ),
      );
    }

    final TeacherAttachment mine = submittedFileFor(a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showAttachmentViewerSheet(context, mine, subtitle: 'Your submission · ${a.submissionStatus}'),
              child: Row(
                children: <Widget>[
                  Container(
                    height: 40, width: 40,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                    child: Icon(mine.kind.icon, size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(mine.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text('Handed in · ${a.submissionStatus} · tap to view', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_forward, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
                  const SizedBox(width: 6),
                  StatusChip(label: a.submissionStatus, color: a.isGraded ? context.accents.success : context.accents.warning, dense: true),
                ],
              ),
            ),
            if (a.isGraded) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.accents.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: Row(children: <Widget>[Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: context.accents.success), const SizedBox(width: 8), Expanded(child: Text('Grade: ${a.grade ?? '—'} · +${a.xpEarned.round()} XP', style: theme.textTheme.bodyMedium))]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Teacher-provided files with mock preview viewer.
class _TeacherFiles extends StatelessWidget {
  const _TeacherFiles({required this.assignment});
  final AssignmentItem assignment;

  @override
  Widget build(BuildContext context) {
    final List<TeacherAttachment> files = teacherFilesFor(assignment);
    return GroupedList(
      children: <Widget>[
        for (int i = 0; i < files.length; i++)
          GroupedRow(
            isFirst: i == 0,
            isLast: i == files.length - 1,
            showChevron: true,
            onTap: () => showAttachmentViewerSheet(context, files[i], subtitle: 'From your teacher · ${files[i].sizeLabel}'),
            leading: Container(
              height: 36, width: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(files[i].kind.icon, size: 18, color: Theme.of(context).colorScheme.primary),
            ),
            trailing: Text(
              files[i].sizeLabel.split('·').first.trim(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(files[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(files[i].sizeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Rubric breakdown that sums to the assignment total.
class _RubricCard extends StatelessWidget {
  const _RubricCard({required this.assignment});
  final AssignmentItem assignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<RubricCriterion> rows = rubricFor(assignment);
    final int total = rows.fold<int>(0, (int s, RubricCriterion r) => s + r.points);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('Total $total pts', style: theme.textTheme.titleSmall)),
                StatusChip(label: '${rows.length} criteria', color: theme.colorScheme.primary, dense: true),
              ],
            ),
            const SizedBox(height: 10),
            for (final RubricCriterion r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(r.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                        Text('${r.points} pts', style: theme.textTheme.labelLarge?.copyWith(color: context.accents.xp, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Text(r.hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total <= 0 ? 0 : (r.points / total).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: context.accents.xp,
                        backgroundColor: context.accents.xp.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            const SheetNote(message: 'Design preview: weights are mocked from total points. Backend will send the real rubric later.'),
          ],
        ),
      ),
    );
  }
}
