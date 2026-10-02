import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/common.dart';
import '../domain/exam_models.dart';
import '../state/exam_providers.dart';

class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ExamListState> exams = ref.watch(examListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(examListProvider),
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          const ProfileMenu(),
        ],
      ),
      body: exams.when(
        loading: () => const SkeletonList(count: 5),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(examListProvider),
        ),
        data: (ExamListState state) {
          if (state.groups.isEmpty) {
            return const EmptyView(
              title: 'No exams yet',
              message: 'When your teacher publishes an exam it will appear here.',
              icon: CupertinoIcons.doc_text,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(examListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: state.groups.length + (state.hasMore ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index == state.groups.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Column(
                      children: [
                        if (state.isLoadingMore)
                          const CupertinoSpinner()
                        else
                          SizedBox(
                            width: 200,
                            child: OutlinedButton(
                              onPressed: () => ref.read(examListProvider.notifier).loadMore(),
                              child: const Text('Load more'),
                            ),
                          ),
                        if (state.loadMoreError != null) ...[
                          const SizedBox(height: 12),
                          // Inline rather than a bare string, and retryable —
                          // a failed page is recoverable without a full refresh.
                          InlineNotice(
                            message: 'Could not load more exams.',
                            tone: InlineNoticeTone.error,
                            icon: CupertinoIcons.exclamationmark_triangle,
                            onRetry: () => ref.read(examListProvider.notifier).loadMore(),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final ExamSeasonGroup group = state.groups[index];
                return FadeSlideIn(
                  delay: AppMotion.stagger(index, capMs: 200),
                  scale: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: group.seasonName,
                        subtitle: '${group.exams.length} ${group.exams.length == 1 ? 'exam' : 'exams'}',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GroupedList(
                          children: [
                            for (int i = 0; i < group.exams.length; i++)
                              _ExamRow(
                                exam: group.exams[i],
                                isFirst: i == 0,
                                isLast: i == group.exams.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam, required this.isFirst, required this.isLast});

  final ExamCard exam;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final (String label, Color color, IconData icon) = switch (exam) {
      ExamCard(isCompleted: true) => (
          'Submitted',
          AppTheme.success,
          CupertinoIcons.checkmark_circle_fill,
        ),
      ExamCard(isOpenNow: true) => ('Open', AppTheme.success, CupertinoIcons.clock_fill),
      ExamCard(isUpcoming: true) => (
          'Upcoming',
          scheme.primary,
          CupertinoIcons.clock,
        ),
      ExamCard(hasEnded: true) => ('Closed', scheme.onSurfaceVariant, CupertinoIcons.lock_fill),
      _ => ('Locked', scheme.onSurfaceVariant, CupertinoIcons.lock_fill),
    };

    // "Opens Sep 20" belongs with the other metadata, not in the status chip,
    // so the chip stays a single short word.
    final String? timing = exam.startsAt != null && (exam.isUpcoming || exam.isOpenNow)
        ? DateFormat.MMMd().add_jm().format(exam.startsAt!)
        : null;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      showChevron: !exam.resultsAvailable,
      onTap: () => context.push('/exams/${exam.id}'),
      leading: StatusChip(label: label, color: color, icon: icon, dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            [
              '${exam.durationMinutes} min',
              '${exam.submittedParts}/${exam.partsCount} parts',
              ?timing,
              ?exam.setTitle,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (exam.resultsAvailable) ...[
            const SizedBox(height: 8),
            // A full-width button inside a row is heavy; this reads as an
            // inline link and keeps the row's height predictable.
            GestureDetector(
              onTap: () => context.push('/exams/${exam.id}/review'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chart_bar_alt_fill, size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Review results',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}