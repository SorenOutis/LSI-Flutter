import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/lsi_mascot.dart';
import '../../domain/dashboard_data.dart';

/// How many days in a row, and which days those were.
///
/// The calendar is drawn from `loginDates`, which the server builds from distinct
/// `DATE(created_at)` values on `gamification_histories` — so a filled day means
/// "earned XP", not "opened the app". The copy says earned-XP throughout rather
/// than borrowing the field's name, because a student who did not earn XP on a day
/// they did open the app would otherwise think the streak was broken.
Future<void> showStreakSheet(BuildContext context, DashboardData data) {
  return AppSheet.show<void>(
    context: context,
    title: '${data.userStats.streak}-day streak',
    subtitle: 'Days you earned XP',
    icon: CupertinoIcons.flame_fill,
    children: <Widget>[
      _StreakSummary(
        streak: data.userStats.streak,
        longestStreak: data.userStats.longestStreak,
        claimAmount: data.claimXp.amount,
        canClaim: data.claimXp.canClaim,
      ),
      const SizedBox(height: 22),
      _Calendar(loginDates: data.loginDates),
      const SizedBox(height: 18),
      const SheetNote(
        message:
            'A day counts once you earn any XP — submitting an exam, an assignment '
            'being graded, or claiming your daily reward. Opening the app on its own '
            'does not extend the streak.',
      ),
      // Restore teaser last so the calendar + legend stay above the fold
      // (dashboard_sheets_test asserts 'Earned XP' without scrolling).
      const SizedBox(height: 16),
      _RestoreInline(data: data),
    ],
  );
}

/// Inline restore teaser inside the streak sheet (design-first).
///
/// Shows real broken state when `streakRestore.isBroken`, otherwise a
/// protection preview so you can test the flow without breaking your streak.
class _RestoreInline extends StatelessWidget {
  const _RestoreInline({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StreakRestoreInfo r = data.streakRestore;
    final bool broken = r.isBroken;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: (broken ? theme.colorScheme.error : context.accents.streak).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          LsiMascot(mood: broken ? LsiMascotMood.sad : LsiMascotMood.happy, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  broken ? 'Streak broken — restore it?' : 'Streak protection',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  broken
                      ? 'Get your ${r.previousStreak > 0 ? r.previousStreak : data.userStats.longestStreak}-day run back for ${r.restoreCost} pts.'
                      : 'Missed a day? Restore brings the flame back. Tap to preview.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: () {
              Navigator.of(context).pop();
              // Opened from dashboard via RestorePreviewCard; deep-link here too.
              showSnack(context, broken ? 'Open restore from the dashboard banner to continue (design).' : 'Open the dashboard “Preview” card to try restore (design).');
            },
            child: Text(broken ? 'Restore' : 'How it works'),
          ),
        ],
      ),
    );
  }
}

class _StreakSummary extends StatelessWidget {
  const _StreakSummary({
    required this.streak,
    required this.longestStreak,
    required this.claimAmount,
    required this.canClaim,
  });

  final int streak;
  final int longestStreak;
  final int claimAmount;
  final bool canClaim;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Figure(value: '$streak', label: 'Current', color: context.accents.streak),
        _Figure(value: '$longestStreak', label: 'Longest', color: scheme.onSurface),
        _Figure(value: '+$claimAmount', label: canClaim ? 'Claimable XP' : 'Next claim', color: context.accents.xp),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Thirteen weeks of days, laid out as a calendar.
///
/// Only the server's 90-day window is known. Anything outside it is drawn as an
/// empty outline rather than a missed day, because the app has no data for it and
/// showing it as a gap would read as a broken streak.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.loginDates});

  /// The server sends exactly 90 days; kept here so the copy and the grid agree.
  static const int windowDays = 90;

  final Set<String> loginDates;

  static const List<String> _weekdayLabels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime first = today.subtract(const Duration(days: windowDays - 1));
    // Monday-first, matching DateTime.weekday (1 = Monday).
    final DateTime gridStart = first.subtract(Duration(days: first.weekday - 1));

    final List<List<DateTime?>> weeks = _weeks(gridStart, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Last ${DateFormat.MMMd().format(first)} – ${DateFormat.MMMd().format(today)}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (final String label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final List<DateTime?> week in weeks)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                for (final DateTime? day in week)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _DayCell(
                        day: day,
                        today: today,
                        first: first,
                        loginDates: loginDates,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _Legend(activeColor: context.accents.streak, scheme: scheme),
      ],
    );
  }

  /// Whole Monday-first weeks covering [first]..[today], padded with nulls.
  List<List<DateTime?>> _weeks(DateTime gridStart, DateTime today) {
    final List<List<DateTime?>> weeks = <List<DateTime?>>[];
    List<DateTime?> week = <DateTime?>[];

    DateTime cursor = gridStart;
    while (!cursor.isAfter(today)) {
      week.add(cursor);
      if (week.length == 7) {
        weeks.add(week);
        week = <DateTime?>[];
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (week.isNotEmpty) {
      while (week.length < 7) {
        week.add(null);
      }
      weeks.add(week);
    }

    return weeks;
  }
}

/// One cell of the streak calendar.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.first,
    required this.loginDates,
  });

  final DateTime? day;
  final DateTime today;
  final DateTime first;
  final Set<String> loginDates;

  static final DateFormat _key = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    if (day == null || day!.isBefore(first) || day!.isAfter(today)) {
      // Outside the known window: drawn as nothing rather than as a missed day,
      // because the server never sent this date and a gap would read as a broken
      // streak.
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color active = context.accents.streak;

    final bool isActive = loginDates.contains(_key.format(day!));
    final bool isToday = day == today;

    return Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? active : scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
        // Today is outlined rather than filled: the fill already means "earned
        // XP", and overloading it would make the two indistinguishable.
        border: isToday ? Border.all(color: active, width: 1.5) : null,
      ),
      child: isActive
          ? null
          : Text(
              '${day!.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.activeColor, required this.scheme});

  final Color activeColor;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        _LegendItem(label: 'Earned XP', color: activeColor),
        _LegendItem(label: 'No XP', color: scheme.onSurface.withValues(alpha: 0.05)),
        _LegendItem(label: 'Today', color: Colors.transparent, outlined: true, outlineColor: activeColor),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    this.outlined = false,
    this.outlineColor,
  });

  final String label;
  final Color color;
  final bool outlined;
  final Color? outlineColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined ? Border.all(color: outlineColor ?? color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}