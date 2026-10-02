import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/common.dart';
import '../../../profile/domain/xp_history.dart';
import '../../../profile/state/profile_providers.dart';
import '../../domain/dashboard_data.dart';

/// Level, progress to the next one, and where the recent XP came from.
///
/// Reads only what the API sends. Badges are deliberately absent: the dashboard
/// computes an earned-badge count and then discards it, and the only badge list
/// in the product is an Inertia page, so there is nothing truthful to show. The
/// sheet states the next badge's level instead, which follows from
/// `BadgeAwardService` awarding every badge whose `required_level` is at or below
/// the level held.
Future<void> showLevelSheet(BuildContext context, UserStats stats) {
  return AppSheet.show<void>(
    context: context,
    title: 'Level ${stats.level}',
    subtitle: 'Season experience',
    icon: CupertinoIcons.rosette,
    children: <Widget>[
      _LevelProgress(stats: stats),
      const SizedBox(height: 20),
      _NextBadge(level: stats.nextLevel, xpToNextLevel: stats.xpToNextLevel),
      const SizedBox(height: 20),
      _WhereXpComesFrom(),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          context.push('/more/profile');
        },
        icon: const Icon(CupertinoIcons.list_bullet, size: 16),
        label: const Text('Open the full XP ledger'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      ),
    ],
  );
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final NumberFormat formatter = NumberFormat.decimalPattern();
    final double remaining = stats.xpToNextLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              formatter.format(stats.totalXP.round()),
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'XP this season',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: stats.levelProgress,
            minHeight: 8,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          remaining <= 0
              ? 'Level ${stats.nextLevel} is unlocked — the next XP raises it.'
              : '${formatter.format(remaining.round())} XP to Level ${stats.nextLevel}',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          'A level is 100 XP, and Level ${stats.nextLevel} begins at '
          '${formatter.format(stats.xpAtNextLevel.round())} XP this season.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }
}

class _NextBadge extends StatelessWidget {
  const _NextBadge({required this.level, required this.xpToNextLevel});

  final int level;
  final double xpToNextLevel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(CupertinoIcons.rosette, size: 20, color: context.accents.xp),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Next badge at Level $level', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 3),
                Text(
                  xpToNextLevel <= 0
                      ? 'You are eligible for it now.'
                      : 'Earn ${xpToNextLevel.round()} more XP to become eligible.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                // Said plainly because the alternative is a student assuming the
                // app forgot to load a feature that does not exist yet.
                SheetNote(
                  message:
                      'Badges are awarded one per level. The app can tell you which level '
                      'the next one unlocks at, but not its name or artwork — the API '
                      'exposes no badge list yet.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The ledger, grouped by what earned it.
///
/// Summarises the page the app has already fetched rather than the whole season:
/// the endpoint is cursor-paginated at 30 rows, so claiming this is "recent
/// activity" would be a lie once a student has more than 30 entries.
class _WhereXpComesFrom extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AsyncValue<XpHistory> history = ref.watch(xpHistoryProvider);

    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Skeleton(height: 68, radius: 10),
      ),
      // The level maths above is already on screen; a failure to load the
      // breakdown is not worth an error state over the top of it.
      error: (Object error, StackTrace _) => const SheetNote(
        message: 'Could not load your recent XP. Pull to refresh the dashboard to try again.',
      ),
      data: (XpHistory data) {
        if (data.isEmpty) {
          return const SheetNote(
            message: 'No XP recorded yet. Submitting an exam or claiming your daily '
                'streak starts the ledger.',
          );
        }

        final Map<XpCategory, double> totals = data.byCategory
          ..removeWhere((XpCategory _, double value) => value == 0);
        final List<MapEntry<XpCategory, double>> rows = totals.entries.toList()
          ..sort((MapEntry<XpCategory, double> a, MapEntry<XpCategory, double> b) =>
              b.value.compareTo(a.value));

        final double largest = rows.fold<double>(
          0,
          (double best, MapEntry<XpCategory, double> e) => e.value.abs() > best ? e.value.abs() : best,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Recent activity', style: theme.textTheme.titleMedium),
                ),
                Text(
                  '${data.entries.length} entries · ${data.netXp.round()} XP net',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final MapEntry<XpCategory, double> row in rows)
              _CategoryBar(
                category: row.key,
                amount: row.value,
                fraction: largest <= 0 ? 0 : (row.value.abs() / largest).clamp(0.06, 1.0),
              ),
            if (data.deductionCount > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Includes ${data.deductionCount} deduction${data.deductionCount == 1 ? '' : 's'}.',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.amount, required this.fraction});

  final XpCategory category;
  final double amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool credit = amount >= 0;
    final Color tone = credit ? context.accents.xp : scheme.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${credit ? '+' : '−'}${amount.abs().round()}',
                style: theme.textTheme.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: tone,
              backgroundColor: tone.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}