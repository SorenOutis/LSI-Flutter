import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../domain/exam_models.dart';
import '../state/exam_providers.dart';

class ExamReviewScreen extends ConsumerStatefulWidget {
  const ExamReviewScreen({super.key, required this.examId});

  final int examId;

  @override
  ConsumerState<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends ConsumerState<ExamReviewScreen> {
  late Future<({List<ExamSubmission> submissions, String examTitle})> _review = _fetch();

  Future<({List<ExamSubmission> submissions, String examTitle})> _fetch() {
    return ref.read(examRepositoryProvider).review(widget.examId);
  }

  void _retry() => setState(() => _review = _fetch());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: FutureBuilder<({List<ExamSubmission> submissions, String examTitle})>(
        future: _review,
        builder: (
          BuildContext context,
          AsyncSnapshot<({List<ExamSubmission> submissions, String examTitle})> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: _retry);
          }

          final ({List<ExamSubmission> submissions, String examTitle}) data = snapshot.data!;
          if (data.submissions.isEmpty) {
            return const EmptyView(
              title: 'Nothing to review yet',
              message: 'Results unlock once the exam closes.',
              icon: Icons.lock_clock_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                data.examTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...data.submissions.map(
                (ExamSubmission submission) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubmissionCard(submission: submission),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission});

  final ExamSubmission submission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<int, Object?> answers = submission.answers;

    final (String label, Color color) = switch (submission) {
      ExamSubmission(gradingFailed: true) => ('Grading failed', theme.colorScheme.error),
      ExamSubmission(status: 'pending_ai') => ('Grading essays…', context.accents.warning),
      ExamSubmission(status: 'pending_review') => ('Awaiting teacher', context.accents.warning),
      _ => ('Graded', context.accents.success),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Part ${submission.examPartId}', style: theme.textTheme.titleSmall),
                ),
                StatusChip(label: label, color: color, dense: true),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  submission.score.isEmpty ? '—' : submission.score,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text('points', style: theme.textTheme.bodySmall),
                const Spacer(),
                if (submission.isLate)
                  StatusChip(label: 'Late', color: theme.colorScheme.error, icon: Icons.schedule_rounded, dense: true),
              ],
            ),
            if (answers.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Your answers', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final MapEntry<int, Object?> entry in answers.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '#${entry.key}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value is List
                              ? (entry.value! as List).map((Object? e) => '$e').join(', ')
                              : '${entry.value ?? '—'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}