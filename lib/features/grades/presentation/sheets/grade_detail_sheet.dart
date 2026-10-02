import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_sheet.dart';
import '../../domain/grade_models.dart';

/// Design-first period grade breakdown. All fields already exist on
/// PeriodGrade (score/max/percentage/remarks/updatedAt) — this just surfaces
/// them. No backend needed.
Future<void> showGradeDetailSheet(
  BuildContext context,
  SubjectGrade subject,
  PeriodGrade period,
) {
  final bool graded = period.isGraded;
  return AppSheet.show<void>(
    context: context,
    title: '${subject.subject} · ${period.label}',
    subtitle: graded ? 'Graded${period.group != null ? ' · ${period.group}' : ''}' : 'Not graded yet',
    icon: graded ? CupertinoIcons.chart_bar_alt_fill : CupertinoIcons.clock,
    children: <Widget>[
      if (!graded) ...<Widget>[
        const SheetNote(message: 'Your teacher has not recorded this period yet. It will appear here with score, remarks and date once posted.'),
      ] else ...<Widget>[
        Center(
          child: Text(
            '${period.percentage.round()}%',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Score ${period.scoreLabel}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (period.percentage / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(height: 12),
        _Row(label: 'Section', value: subject.sectionName),
        _Row(label: 'Level', value: subject.schoolLevelLabel),
        if (period.remarks != null && period.remarks!.isNotEmpty)
          _Row(label: 'Remarks', value: period.remarks!),
        if (period.updatedAt != null) _Row(label: 'Posted', value: period.updatedAt!),
        const SizedBox(height: 8),
        SheetNote(
          message: subject.isComplete
              ? 'Final standing for this subject: ${subject.standing?.toStringAsFixed(1) ?? '—'}.'
              : 'Provisional — remaining periods can still move the average.',
        ),
      ],
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
