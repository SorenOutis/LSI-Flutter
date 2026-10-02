import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/common.dart';
import '../domain/exam_models.dart';
import '../state/exam_providers.dart';
import 'widgets/question_input.dart';

class ExamTakingScreen extends ConsumerStatefulWidget {
  const ExamTakingScreen({super.key, required this.examId, required this.partId});

  final int examId;
  final int partId;

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen> {
  ({int examId, int partId}) get _arg => (examId: widget.examId, partId: widget.partId);

  Timer? _clockTicker;
  DateTime? _deadline;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    // Start (or resume) the server clock once the draft has loaded, so the
    // deadline shown is the authoritative one rather than a local guess.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startClock());
    });
  }

  Future<void> _startClock() async {
    final DateTime? deadline = await ref.read(partAnswersProvider(_arg).notifier).startClock();
    if (!mounted || deadline == null) return;

    setState(() => _deadline = deadline);
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PartAnswersState> answers = ref.watch(partAnswersProvider(_arg));
    final NavigatorState navigator = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        if (await _confirmLeave(context) && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exam'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmLeave(context) && mounted) navigator.pop();
            },
          ),
          actions: [
            answers.maybeWhen(
              data: (PartAnswersState state) => _SaveIndicator(state: state),
              orElse: () => const SizedBox.shrink(),
            ),
            if (_deadline != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: _Countdown(deadline: _deadline!)),
              ),
          ],
        ),
        body: answers.when(
          loading: () => const LoadingView(message: 'Loading your questions…'),
          error: (Object error, StackTrace _) => ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(partAnswersProvider(_arg)),
          ),
          data: (PartAnswersState state) => Column(
            children: [
              Expanded(child: _QuestionList(state: state)),
              _SubmitBar(state: state, submitting: _submitting, onSubmit: () => _submit(state)),
            ],
          ),
        ),
      ),
    );
  }

  /// Flush pending edits before asking.
  ///
  /// An unanswered-looking exit must never cost the student work that was
  /// already typed but not yet saved, so the save happens *before* the dialog —
  /// otherwise a student who hits back during a connection blip loses the part.
  Future<bool> _confirmLeave(BuildContext dialogHostContext) async {
    final PartAnswersState? state = ref.read(partAnswersProvider(_arg)).value;
    if (state == null) return true;

    await ref.read(partAnswersProvider(_arg).notifier).save();
    if (!mounted || !dialogHostContext.mounted) return false;

    return await showDialog<bool>(
          context: dialogHostContext,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Leave this part?'),
            content: const Text(
              'Your answers are saved, but this part is only submitted when you tap Submit.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep working'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _submit(PartAnswersState state) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Submit this part?'),
        content: Text(
          state.isComplete
              ? 'All ${state.questionCount} questions are answered. You cannot change your answers after submitting.'
              : '${state.answeredCount} of ${state.questionCount} questions are answered. Unanswered questions will be marked wrong. You cannot change your answers after submitting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep working'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);

    try {
      final SubmitPartResult result = await ref
          .read(partAnswersProvider(_arg).notifier)
          .submit();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          icon: Icon(
            result.isPendingGrading ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
            color: result.isPendingGrading ? context.accents.warning : context.accents.success,
          ),
          title: Text(result.isPendingGrading ? 'Submitted' : 'Part submitted'),
          content: Text(
            result.isPendingGrading
                ? (result.awaitingTeacherReview
                    ? 'Your answers are saved. Your essay is waiting for your teacher to grade.'
                    : 'Your answers are saved. Your essay is being graded now — this usually takes a moment.')
                : 'You scored ${result.score.toStringAsFixed(2)} points on this part.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) context.go('/exams/${widget.examId}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showSnack(context, '$error', isError: true);
    }
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});

  final PartAnswersState state;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (state) {
      PartAnswersState(isSaving: true) => (
        Icons.sync_rounded,
        'Saving',
        Theme.of(context).colorScheme.primary,
      ),
      PartAnswersState(saveError: final Object error) => (
        Icons.cloud_off_rounded,
        'Save failed',
        Theme.of(context).colorScheme.error,
      ),
      PartAnswersState(hasUnsavedChanges: true) => (
        Icons.edit_rounded,
        'Unsaved',
        context.accents.warning,
      ),
      _ => (Icons.cloud_done_rounded, 'Saved', context.accents.success),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: state.saveError != null ? '${state.saveError}' : label,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final Duration remaining = deadline.difference(DateTime.now());
    final bool expired = remaining.isNegative;
    final Duration shown = expired ? Duration.zero : remaining;

    final String label = expired
        ? 'Time up'
        : '${shown.inHours.toString().padLeft(2, '0')}:'
              '${(shown.inMinutes % 60).toString().padLeft(2, '0')}:'
              '${(shown.inSeconds % 60).toString().padLeft(2, '0')}';

    // Amber under 5 minutes, red under 1 — the same thresholds the web client
    // uses so the two surfaces agree.
    final Color color = expired || shown.inMinutes < 1
        ? Theme.of(context).colorScheme.error
        : shown.inMinutes < 5
        ? context.accents.warning
        : Theme.of(context).colorScheme.onSurfaceVariant;

    // AnimatedContainer smooths the amber→red snap so a threshold crossing
    // pulses instead of flashing.
    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _QuestionList extends ConsumerWidget {
  const _QuestionList({required this.state});

  final PartAnswersState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: state.questions.length,
      itemBuilder: (BuildContext context, int index) {
        final ExamQuestion question = state.questions[index];
        final Object? answer = state.answers[question.index];

        return FadeSlideIn(
          delay: AppMotion.stagger(index, capMs: 240),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${question.index}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.type.label,
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        '${question.points.toStringAsFixed(0)} pts',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(question.text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.4)),
                  const SizedBox(height: 14),
                  QuestionInput(
                    question: question,
                    answer: answer,
                    onChanged: (Object? value) => ref
                        .read(partAnswersProvider((examId: state.examId, partId: state.partId)).notifier)
                        .answer(
                          question.index,
                          value,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.state, required this.submitting, required this.onSubmit});

  final PartAnswersState state;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int remaining = state.questionCount - state.answeredCount;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.answeredCount}/${state.questionCount} answered'
                      '${remaining > 0 ? ' · $remaining remaining' : ''}',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    '${state.answeredPoints.toStringAsFixed(0)} / ${state.totalPoints.toStringAsFixed(0)} pts',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: submitting || state.questionCount == 0 ? null : onSubmit,
                icon: submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(submitting ? 'Submitting…' : 'Submit part'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}