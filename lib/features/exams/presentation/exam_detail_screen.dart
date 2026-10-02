import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../domain/exam_models.dart';
import '../state/exam_providers.dart';

class ExamDetailScreen extends ConsumerWidget {
  const ExamDetailScreen({super.key, required this.examId});

  final int examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ExamDetail> detail = ref.watch(examDetailProvider(examId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exam')),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(examDetailProvider(examId)),
        ),
        data: (ExamDetail exam) => _DetailBody(exam: exam),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.exam});

  final ExamDetail exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(exam.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (exam.sectionName != null)
              StatusChip(label: exam.sectionName!, color: theme.colorScheme.primary, icon: Icons.groups_rounded),
            if (exam.setTitle != null)
              StatusChip(label: 'Set: ${exam.setTitle!}', color: theme.colorScheme.tertiary, icon: Icons.label_rounded),
            StatusChip(
              label: exam.isOpenNow
                  ? 'Open now'
                  : exam.isUpcoming
                  ? 'Upcoming'
                  : 'Closed',
              color: exam.isOpenNow ? AppTheme.success : theme.colorScheme.outline,
              icon: exam.isOpenNow ? Icons.play_circle_outline_rounded : Icons.schedule_rounded,
            ),
            if (exam.durationMinutes > 0)
              StatusChip(
                label: '${exam.durationMinutes} min per part',
                color: theme.colorScheme.outline,
                icon: Icons.timer_outlined,
              ),
          ],
        ),
        if (exam.description != null && exam.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(exam.description!, style: theme.textTheme.bodyMedium),
        ],
        if (exam.startsAt != null) ...[
          const SizedBox(height: 12),
          Text(
            exam.isUpcoming
                ? 'Opens ${DateFormat.yMMMd().add_jm().format(exam.startsAt!)}'
                : 'Opened ${DateFormat.yMMMd().add_jm().format(exam.startsAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (exam.endsAt != null)
            Text(
              'Closes ${DateFormat.yMMMd().add_jm().format(exam.endsAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
        const SectionHeader(title: 'Parts'),
        if (exam.parts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('This exam has no parts assigned to you yet.'),
            ),
          )
        else
          ...exam.parts.asMap().entries.map(
                (MapEntry<int, ExamPart> entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PartCard(exam: exam, part: entry.value, fallbackTitle: 'Part ${entry.key + 1}'),
                ),
              ),
        if ((exam.xpAward?.totalXp ?? 0) > 0) ...[
          const SectionHeader(title: 'XP earned'),
          _XpAwardCard(award: exam.xpAward!),
        ],
      ],
    );
  }
}

class _PartCard extends ConsumerWidget {
  const _PartCard({required this.exam, required this.part, required this.fallbackTitle});

  final ExamDetail exam;
  final ExamPart part;

  /// Used when the part carries no title; parts are otherwise anonymous.
  final String fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ExamSubmission? submission = exam.submissions[part.id];
    final DateTime? deadline = exam.deadlineFor(part.id);
    final AnswerDraft? draft = exam.answerDrafts[part.id];

    final bool hasDraft = draft != null && draft.answers.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    part.title ?? fallbackTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (submission != null)
                  StatusChip(
                    label: submission.isPendingGrading ? 'Grading' : 'Submitted',
                    color: submission.isPendingGrading ? AppTheme.xp : AppTheme.success,
                    icon: submission.isPendingGrading
                        ? Icons.hourglass_top_rounded
                        : Icons.check_circle_outline_rounded,
                    dense: true,
                  )
                else if (hasDraft)
                  StatusChip(
                    label: 'In progress',
                    color: AppTheme.xp,
                    icon: Icons.edit_note_rounded,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.help_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${part.questions.length} questions',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (deadline != null) ...[
                  const SizedBox(width: 14),
                  Icon(Icons.schedule_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${DateFormat.MMMd().add_jm().format(deadline)}',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            if (part.instructions != null && part.instructions!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(part.instructions!, style: theme.textTheme.bodySmall),
            ],
            if (submission == null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: exam.isOpenNow
                    ? () => context.push('/exams/${exam.id}/parts/${part.id}')
                    : null,
                child: Text(hasDraft ? 'Resume part' : 'Start part'),
              ),
              if (!exam.isOpenNow) ...[
                const SizedBox(height: 8),
                Text(
                  exam.isUpcoming
                      ? 'This exam has not opened yet.'
                      : 'This exam is closed. Answers can no longer be submitted.',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ] else if (submission.isPendingGrading) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => context.push('/exams/${exam.id}/parts/${part.id}/status'),
                icon: const Icon(Icons.hourglass_top_rounded),
                label: const Text('Check grading status'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _XpAwardCard extends StatelessWidget {
  const _XpAwardCard({required this.award});

  final ExamXpAward award;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '+${award.totalXp} XP',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.xp,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _XpRow(label: 'Completion', value: award.completionXp),
            _XpRow(label: 'On time', value: award.onTimeXp),
            _XpRow(
              label: award.accuracyPending ? 'Accuracy (grading…)' : 'Accuracy',
              value: award.accuracyXp,
              detail: award.accuracyPercentage == null ? null : '${award.accuracyPercentage!.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _XpRow extends StatelessWidget {
  const _XpRow({required this.label, required this.value, this.detail});

  final String label;
  final int value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          if (detail != null) ...[
            Text(detail!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 12),
          ],
          Text('+$value XP', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}