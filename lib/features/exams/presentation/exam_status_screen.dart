import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../domain/exam_models.dart';
import '../state/exam_providers.dart';

class ExamPartStatusScreen extends ConsumerStatefulWidget {
  const ExamPartStatusScreen({super.key, required this.examId, required this.partId});

  final int examId;
  final int partId;

  @override
  ConsumerState<ExamPartStatusScreen> createState() => _ExamPartStatusScreenState();
}

class _ExamPartStatusScreenState extends ConsumerState<ExamPartStatusScreen> {
  Timer? _poll;
  ExamPartStatus? _status;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_pollOnce());
    _poll = Timer.periodic(AppConfig.examPollInterval, (_) => unawaited(_pollOnce()));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    if (!mounted) return;

    try {
      final ExamPartStatus status = await ref
          .read(examRepositoryProvider)
          .partStatus(examId: widget.examId, partId: widget.partId);

      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });

      // Stop polling once the outcome can no longer change. `isSettled` covers
      // the scored, teacher-review and failed cases; a part still queued for AI
      // keeps the poller alive.
      if (status.isSettled) _poll?.cancel();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      // A 403/404 will never resolve by waiting; only keep polling on transport
      // failures.
      if (error.isForbidden || error.statusCode == 404) _poll?.cancel();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grading'),
        actions: [
          if (_status != null && !(_status!.isSettled))
            IconButton(
              tooltip: 'Refresh',
              onPressed: _pollOnce,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: switch ((_error, _status)) {
        (final Object error, null) => ErrorView(message: '$error', onRetry: _pollOnce),
        (_, null) => const LoadingView(message: 'Checking your submission…'),
        (_, final ExamPartStatus status) =>
          _StatusBody(status: status, onRetry: _pollOnce, examId: widget.examId),
      },
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.status, required this.onRetry, required this.examId});

  final ExamPartStatus status;
  final Future<void> Function() onRetry;

  /// Where "Back to exam" lands. Passed in because this widget does not know the
  /// exam it belongs to.
  final int examId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final (IconData icon, Color color, String title, String message) = switch (status) {
      ExamPartStatus(gradingFailed: true) => (
        Icons.error_outline_rounded,
        theme.colorScheme.error,
        'Grading failed',
        'Your answers were saved, but this part could not be graded. Your teacher can review it manually.',
      ),
      ExamPartStatus(awaitingTeacherReview: true) => (
        Icons.schedule_rounded,
        context.accents.warning,
        'Waiting for your teacher',
        'Your objective questions are graded. Your essay will be marked by your teacher.',
      ),
      ExamPartStatus(status: 'pending_ai') => (
        Icons.hourglass_top_rounded,
        context.accents.warning,
        'Grading your essay…',
        'This usually takes less than a minute. You can safely leave this screen.',
      ),
      ExamPartStatus(scored: true, score: final double score) => (
        Icons.check_circle_rounded,
        context.accents.success,
        'Graded',
        'You scored ${score.toStringAsFixed(2)} points on this part.',
      ),
      _ => (
        Icons.hourglass_top_rounded,
        context.accents.warning,
        'Submitted',
        'This part is being processed.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!status.isSettled)
              SizedBox(
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      height: 88,
                      width: 88,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    Icon(icon, size: 32, color: color),
                  ],
                ),
              )
            else
              Icon(icon, size: 72, color: color),
            const SizedBox(height: 20),
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (status.isLate) ...[
              const SizedBox(height: 12),
              StatusChip(
                label: 'Submitted late',
                color: theme.colorScheme.error,
                icon: Icons.schedule_rounded,
                dense: true,
              ),
            ],
            if (status.xpAward != null && status.xpAward!.totalXp > 0) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '+${status.xpAward!.totalXp} XP',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.accents.warning,
                        ),
                      ),
                      if (status.xpAward!.accuracyPending)
                        Text(
                          'Accuracy XP pending until every essay is graded.',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (status.isSettled)
              FilledButton.tonal(
                onPressed: () => context.go('/exams/$examId'),
                child: const Text('Back to exam'),
              )
            else
              TextButton(onPressed: onRetry, child: const Text('Check again')),
          ],
        ),
      ),
    );
  }
}