import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../domain/dashboard_data.dart';

/// Why a reward is worth a different amount today.
///
/// Opened from either claim card. The amounts are not arbitrary: the daily claim
/// is a base value plus a streak bonus that grows one XP per five days and caps at
/// four, and the bonus claim is a flat amount the school sets. A student seeing
/// "11 XP" with no explanation is the exact person who stops bothering to check
/// in, so the arithmetic is spelled out.
Future<void> showClaimSheet({
  required BuildContext context,
  required DashboardData data,
  required bool isBonus,
}) {
  final ClaimStatus claim = isBonus ? data.bonusXp : data.claimXp;

  return AppSheet.show<void>(
    context: context,
    title: isBonus ? 'Bonus XP' : 'Daily streak reward',
    subtitle: isBonus ? 'A one-off bonus on top of your streak' : 'Claimed once per day',
    icon: CupertinoIcons.gift_fill,
    children: <Widget>[
      _Status(claim: claim, isBonus: isBonus),
      const SizedBox(height: 20),
      if (isBonus) const _BonusExplainer() else _DailyExplainer(streak: data.userStats.streak),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.claim, required this.isBonus});

  final ClaimStatus claim;
  final bool isBonus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color amber = context.accents.xp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '+${claim.amount} XP',
            style: theme.textTheme.titleMedium?.copyWith(color: amber, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _statusLine(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _statusLine() {
    if (claim.canClaim) return 'Available to claim right now.';
    if (claim.nextClaimAt == null) return 'Not available at the moment.';

    final DateTime next = claim.nextClaimAt!;
    final DateTime now = DateTime.now();
    final bool tomorrow = next.day != now.day;

    // `nextClaimAt` is the start of the following day, so saying "in 8 hours"
    // would misstate a rule that is really a calendar day.
    return tomorrow
        ? 'Claimable again from ${DateFormat.MMMEd().format(next)}.'
        : 'Claimable again tomorrow.';
  }
}

class _DailyExplainer extends StatelessWidget {
  const _DailyExplainer({required this.streak});

  final int streak;

  /// `ClaimXpService::MAX_STREAK_BONUS`.
  static const int _maxStreakBonus = 4;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('How the amount is worked out', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(
          'A base amount, plus one extra XP for every five days in your streak, up '
          'to a bonus of $_maxStreakBonus.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 14),
        _StreakLadder(streak: streak, maxBonus: _maxStreakBonus),
        const SizedBox(height: 14),
        SheetNote(
          message: streak >= _maxStreakBonus * 5
              ? 'Your streak is past $_maxStreakBonus*5 days, so the bonus is already maxed out. '
                  'The base amount is all that is left to earn.'
              : 'At ${_maxStreakBonus * 5} days the bonus caps. You are ${(streak ~/ 5).clamp(0, _maxStreakBonus)} '
                  'of $_maxStreakBonus towards it.',
          icon: CupertinoIcons.info_circle,
        ),
      ],
    );
  }
}

/// Days to streak, and the bonus each one buys.
///
/// Shown as a ladder rather than a formula because the rule only bites at the
/// five-day marks; a sentence like "3 of 4" hides that nothing changes until day 5.
class _StreakLadder extends StatelessWidget {
  const _StreakLadder({required this.streak, required this.maxBonus});

  /// A literal dollar sign, kept in a raw string so it stays unambiguous next to
  /// an interpolation.
  static const String _currency = r'$';

  final int streak;
  final int maxBonus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int earned = (streak ~/ 5).clamp(0, maxBonus);

    return Row(
      children: <Widget>[
        for (int bonus = 0; bonus <= maxBonus; bonus++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: bonus <= earned
                    ? context.accents.xp.withValues(alpha: 0.14)
                    : scheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    // The currency sign is interpolated from a constant rather
                    // than typed inline: `'+$$bonus'` prints the literal string
                    // "+$bonus", because a `$` not followed by an identifier is
                    // just a dollar sign.
                    '+$_currency$bonus',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: bonus <= earned ? context.accents.xp : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bonus * 5}d',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (bonus < maxBonus) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _BonusExplainer extends StatelessWidget {
  const _BonusExplainer();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('How this works', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(
          'A flat bonus the school sets, separate from your daily streak reward. '
          'It does not grow with your streak — a long streak only makes the daily '
          'claim worth more.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 14),
        const SheetNote(
          message:
              'Whether a bonus is available at all is a setting your school controls. '
              'When it is switched off, the card disappears rather than showing zero.',
        ),
      ],
    );
  }
}