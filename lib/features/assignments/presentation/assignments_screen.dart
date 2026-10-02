import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common.dart';
import '../domain/assignment_models.dart';
import '../state/assignment_providers.dart';

/// Outstanding work first, handed-in work after it. A student opening this page
/// is answering "what do I still owe?", not "what have I done?".
class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AssignmentsData> assignments = ref.watch(assignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(assignmentsProvider),
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          const ProfileMenu(),
        ],
      ),
      body: assignments.when(
        loading: () => const SkeletonList(count: 5),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(assignmentsProvider),
        ),
        data: (AssignmentsData data) {
          if (data.isEmpty) {
            return const EmptyView(
              title: 'No assignments yet',
              message: 'Work given to your sections will appear here, with its deadline and your grade once it is marked.',
              icon: CupertinoIcons.doc_plaintext,
            );
          }

          final List<AssignmentItem> outstanding = data.outstanding;
          final List<AssignmentItem> completed = data.completed;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(assignmentsProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _SummaryCard(data: data),
                ),
                if (outstanding.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: 'Outstanding',
                    subtitle: '${outstanding.length} ${outstanding.length == 1 ? 'assignment' : 'assignments'} to hand in',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GroupedList(
                      children: <Widget>[
                        for (int i = 0; i < outstanding.length; i++)
                          _AssignmentRow(
                            assignment: outstanding[i],
                            isFirst: i == 0,
                            isLast: i == outstanding.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
                if (completed.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: 'Handed in',
                    subtitle: '${completed.length} submitted',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GroupedList(
                      children: <Widget>[
                        for (int i = 0; i < completed.length; i++)
                          _AssignmentRow(
                            assignment: completed[i],
                            isFirst: i == 0,
                            isLast: i == completed.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final AssignmentsData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;
    final int overdue = data.overdueCount;

    if (overdue == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(CupertinoIcons.checkmark_seal_fill, size: 20, color: accents.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.outstanding.isEmpty
                      ? 'Everything is handed in.'
                      : 'Nothing overdue. ${data.outstanding.length} still open.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: scheme.error.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(CupertinoIcons.exclamationmark_circle_fill, size: 20, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$overdue ${overdue == 1 ? 'assignment is' : 'assignments are'} past the deadline.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.assignment, required this.isFirst, required this.isLast});

  final AssignmentItem assignment;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;

    final ({Color color, IconData icon}) leading = switch (assignment) {
      _ when assignment.isGraded => (color: accents.success, icon: CupertinoIcons.checkmark_circle_fill),
      _ when assignment.submitted => (color: accents.warning, icon: CupertinoIcons.hourglass),
      _ when assignment.isOverdue => (color: scheme.error, icon: CupertinoIcons.exclamationmark_circle_fill),
      _ => (color: scheme.onSurfaceVariant, icon: CupertinoIcons.doc_plaintext),
    };

    final Color dueTone = assignment.isOverdue
        ? scheme.error
        : assignment.isDueSoon
        ? accents.warning
        : scheme.onSurfaceVariant;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      onTap: () => context.push('/more/assignments/${assignment.id}'),
      showChevron: true,
      leading: Icon(leading.icon, size: 22, color: leading.color),
      trailing: assignment.isGraded
          ? StatusChip(label: assignment.grade ?? 'Graded', color: accents.success, dense: true)
          : Text(
              '${assignment.pointsPossible} pts',
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            assignment.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: assignment.isOverdue ? scheme.error : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            assignment.dueLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: dueTone,
              fontWeight: assignment.isOverdue || assignment.isDueSoon ? FontWeight.w600 : null,
            ),
          ),
          if (assignment.submitted && assignment.feedback != null) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(CupertinoIcons.chat_bubble_text, size: 13, color: scheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assignment.feedback!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
          if (assignment.isGroupWork) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(CupertinoIcons.person_2, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    assignment.memberCount > 0
                        ? 'Group of ${assignment.memberCount} · up to ${assignment.groupMax}'
                        : 'Group work · ${assignment.groupMin}–${assignment.groupMax} people',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          if (assignment.hasUnseenFeedback)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: StatusChip(label: 'New feedback', color: accents.xp, dense: true),
            ),
        ],
      ),
    );
  }
}
