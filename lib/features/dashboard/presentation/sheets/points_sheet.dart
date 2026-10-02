import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../domain/dashboard_data.dart';

/// Points, and what the app can honestly say about them.
///
/// Short by design. `season_progress.points` is the only points figure the API
/// sends: `XpHistoryController` returns `amount_xp` but not `amount_points`, and
/// the two are awarded independently, so a per-category points breakdown cannot be
/// derived from the ledger and must not be faked by reusing the XP figures.
Future<void> showPointsSheet(BuildContext context, DashboardData data) {
  final UserStats stats = data.userStats;
  final NumberFormat formatter = NumberFormat.decimalPattern();

  return AppSheet.show<void>(
    context: context,
    title: 'Points',
    subtitle: 'A separate tally from XP',
    icon: CupertinoIcons.checkmark_seal_fill,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            formatter.format(stats.points.round()),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'this season',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const SheetNote(
        icon: CupertinoIcons.exclamationmark_triangle,
        message:
            'Points and XP are awarded separately, and the ledger only records XP. '
            'This is the season total the school server sends — there is no per-activity '
            'points breakdown available to the app yet.',
      ),
      const SizedBox(height: 16),
      _Comparison(stats: stats),
    ],
  );
}

/// XP and points side by side, to head off the obvious question.
///
/// The one relationship that does hold: XP drives the level, points do not.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Row(
          icon: CupertinoIcons.star_fill,
          color: context.accents.xp,
          label: 'Season XP',
          value: stats.totalXP.round().toString(),
          note: 'Decides your level',
        ),
        const SizedBox(height: 10),
        _Row(
          icon: CupertinoIcons.checkmark_seal_fill,
          color: context.accents.success,
          label: 'Points',
          value: stats.points.round().toString(),
          note: 'Recorded by the school',
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: theme.textTheme.bodyLarge),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}