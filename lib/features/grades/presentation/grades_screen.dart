import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common.dart';
import '../domain/grade_models.dart';
import '../state/grade_providers.dart';
import 'sheets/grade_detail_sheet.dart';

/// Per-subject grades, grouped the way the registrar reports them: a standing
/// for the subject, then each period behind it.
class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GradesData> grades = ref.watch(gradesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grades'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(gradesProvider),
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          const ProfileMenu(),
        ],
      ),
      body: grades.when(
        loading: () => const SkeletonList(count: 4),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(gradesProvider),
        ),
        data: (GradesData data) {
          if (data.isEmpty) {
            return const EmptyView(
              title: 'No grades yet',
              message: 'Once your teacher records a period grade for one of your subjects it will show up here.',
              icon: CupertinoIcons.chart_bar,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(gradesProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _SummaryCard(data: data),
                ),
                for (final SubjectGrade subject in data.subjects) ...<Widget>[
                  SectionHeader(
                    title: subject.subject,
                    subtitle: '${subject.sectionName} · ${subject.schoolLevelLabel}',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SubjectCard(subject: subject),
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

  final GradesData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double? average = data.overallAverage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  average == null ? '—' : average.toStringAsFixed(1),
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Overall average',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${data.subjects.length} ${data.subjects.length == 1 ? 'subject' : 'subjects'} enrolled',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.completedSubjects == data.subjects.length
                        ? 'Every subject has a final grade.'
                        : '${data.completedSubjects} of ${data.subjects.length} have a final grade, the rest are provisional.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final SubjectGrade subject;

  /// Philippine grading: 75 is the passing mark, so the ramp is anchored there
  /// rather than at an arbitrary 50/80 split.
  static Color _tone(ColorScheme scheme, AppColors accents, double? value) {
    if (value == null) return scheme.onSurfaceVariant;
    if (value >= 90) return accents.success;
    if (value >= 80) return scheme.primary;
    if (value >= 75) return accents.warning;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;

    final double? standing = subject.standing;
    final Color tone = _tone(scheme, accents, standing);
    final double progress = subject.periodCount == 0 ? 0 : subject.gradedCount / subject.periodCount;

    return GroupedList(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    standing == null ? '—' : standing.toStringAsFixed(1),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: tone),
                  ),
                  const SizedBox(width: 8),
                  // Flexible so a longer status or a larger text scale shrinks it
                  // instead of overflowing this row.
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: StatusChip(
                        label: subject.isComplete ? 'Final' : 'Provisional',
                        color: subject.isComplete ? accents.success : accents.warning,
                        dense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text(
                    'Periods graded',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    '${subject.gradedCount} of ${subject.periodCount}',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < subject.periods.length; i++)
          _PeriodRow(
            period: subject.periods[i],
            tone: _tone(scheme, accents, subject.periods[i].percentage),
            showGroup: subject.periods[i].group != null,
            onTap: () => showGradeDetailSheet(context, subject, subject.periods[i]),
          ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.tone, required this.showGroup, this.onTap});

  final PeriodGrade period;
  final Color tone;
  final bool showGroup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool graded = period.score.isNotEmpty;

    return Column(
      children: <Widget>[
        Divider(height: 1, indent: 16, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          period.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: graded ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                        ),
                        // Senior-high quarters only make sense with their semester.
                        if (showGroup)
                          Text(
                            period.group!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (graded) ...<Widget>[
                    Text(
                      period.scoreLabel,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${period.percentage.round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(color: tone, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.chevron_forward, size: 14, color: scheme.onSurface.withValues(alpha: 0.25)),
                  ] else
                    Text(
                      'Not graded',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
