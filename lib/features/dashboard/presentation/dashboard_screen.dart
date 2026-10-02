import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import 'sheets/claim_sheet.dart';
import 'sheets/level_sheet.dart';
import 'sheets/points_sheet.dart';
import 'sheets/restore_streak_sheet.dart';
import 'sheets/streak_sheet.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/state/auth_providers.dart';
import '../domain/dashboard_data.dart';
import '../state/dashboard_providers.dart';

/// The home screen: who you are, what is waiting for you, and how you are doing.
///
/// The order is deliberate — identity and progress first, then anything the
/// student can *act* on (rewards, exams, assignments), and only then the
/// ambient material (consistency, announcements, rankings). A student opening
/// the app between classes should be able to answer "do I have anything due?"
/// without scrolling past a wall of stats.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardData> dashboard = ref.watch(dashboardProvider);
    final AppUser? user = ref.watch(sessionProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dashboardProvider),
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          const ProfileMenu(),
        ],
      ),
      body: dashboard.when(
        loading: () => const _DashboardSkeleton(),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (DashboardData data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: FadeSlideIn(
                  child: _Hero(
                    stats: data.userStats,
                    user: user,
                    seasonName: data.activeSeasonName,
                    standing: _primaryStanding(data),
                    onStreakTap: () => showStreakSheet(context, data),
                    onPointsTap: () => showPointsSheet(context, data),
                  ),
                ),
              ),

              // Both rewards can be claimable at once; each gets its own card so
              // the student never has to guess which one a single banner meant.
              for (int r = 0; r < _claimableRewards(data).length; r++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FadeSlideIn(
                    delay: AppMotion.stagger(r + 1),
                    child: _RewardCard(reward: _claimableRewards(data)[r], data: data),
                  ),
                ),

              // Design-first: restore banner / protection preview. Always
              // visible for testing; backend later drives isBroken.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FadeSlideIn(
                  delay: AppMotion.stagger(2),
                  child: RestorePreviewCard(data: data),
                ),
              ),

              if (data.upcomingExams.isNotEmpty) ...<Widget>[
                SectionHeader(
                  title: 'Up next',
                  subtitle: 'Exams you can take now or soon',
                  trailing: TextButton(
                    onPressed: () => context.go('/exams'),
                    child: const Text('See all'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FadeSlideIn(
                    delay: AppMotion.stagger(3),
                    scale: false,
                    child: GroupedList(
                      children: <Widget>[
                        for (int i = 0; i < data.upcomingExams.length; i++)
                          _UpcomingExamRow(
                            exam: data.upcomingExams[i],
                            isFirst: i == 0,
                            isLast: i == data.upcomingExams.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              if (data.assignments.isNotEmpty) ...<Widget>[
                const SectionHeader(title: 'Assignments'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FadeSlideIn(
                    delay: AppMotion.stagger(4),
                    scale: false,
                    child: GroupedList(
                      children: <Widget>[
                        for (int i = 0; i < data.assignments.length; i++)
                          _AssignmentRow(
                            assignment: data.assignments[i],
                            isFirst: i == 0,
                            isLast: i == data.assignments.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              if (data.loginDates.isNotEmpty) ...<Widget>[
                const SectionHeader(title: 'Consistency'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FadeSlideIn(
                    delay: AppMotion.stagger(5),
                    child: _ActivityCard(
                      dates: data.loginDates,
                      streak: data.userStats.streak,
                      longestStreak: data.userStats.longestStreak,
                    ),
                  ),
                ),
              ],

              if (data.announcements.isNotEmpty) ...<Widget>[
                const SectionHeader(title: 'Announcements'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FadeSlideIn(
                    delay: AppMotion.stagger(6),
                    scale: false,
                    child: GroupedList(
                      children: <Widget>[
                        for (int i = 0; i < data.announcements.length; i++)
                          _AnnouncementRow(
                            announcement: data.announcements[i],
                            isFirst: i == 0,
                            isLast: i == data.announcements.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              for (int b = 0; b < data.sectionLeaderboards.length; b++) ...<Widget>[
                SectionHeader(
                  title: data.sectionLeaderboards[b].sectionName,
                  subtitle: data.sectionLeaderboards[b].totalPlayers > 0
                      ? 'You are #${data.sectionLeaderboards[b].userRank} of ${data.sectionLeaderboards[b].totalPlayers}'
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FadeSlideIn(
                    delay: AppMotion.stagger(7 + b),
                    scale: false,
                    child: _Leaderboard(board: data.sectionLeaderboards[b]),
                  ),
                ),
              ],

              // Every list coming back empty should say so, rather than leaving
              // the student staring at a single card and a lot of nothing.
              if (_isBare(data))
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyView(
                    title: 'Nothing to show yet',
                    message: 'Exams, assignments and announcements will appear here once your teachers publish them.',
                    icon: CupertinoIcons.tray,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isBare(DashboardData data) {
    return data.upcomingExams.isEmpty &&
        data.assignments.isEmpty &&
        data.announcements.isEmpty &&
        data.sectionLeaderboards.isEmpty;
  }
}

String _greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Where the student stands in their section, if any section is ranked.
({int rank, int players, String section})? _primaryStanding(DashboardData data) {
  for (final SectionLeaderboard board in data.sectionLeaderboards) {
    if (board.leaderboardEnabled && board.totalPlayers > 0) {
      return (rank: board.userRank, players: board.totalPlayers, section: board.sectionName);
    }
  }
  return null;
}

typedef _Reward = ({ClaimStatus claim, bool isBonus});

List<_Reward> _claimableRewards(DashboardData data) {
  return <_Reward>[
    if (data.claimXp.canClaim) (claim: data.claimXp, isBonus: false),
    if (data.bonusXp.canClaim) (claim: data.bonusXp, isBonus: true),
  ];
}

/// Identity and progress, in one card: the level ring, who you are, and the
/// three numbers that tell you how the season is going.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.stats,
    required this.user,
    required this.seasonName,
    required this.standing,
    required this.onStreakTap,
    required this.onPointsTap,
  });

  final UserStats stats;
  final AppUser? user;
  final String? seasonName;
  final ({int rank, int players, String section})? standing;

  /// The streak and points sheets need the whole dashboard payload, not just the
  /// number in the strip, so their openers are passed in from the screen that
  /// already holds it.
  final VoidCallback onStreakTap;
  final VoidCallback onPointsTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _LevelRing(
                  level: stats.level,
                  progress: stats.levelProgress,
                  onTap: () => showLevelSheet(context, stats),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _greetingFor(DateTime.now()),
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.firstNameOrTitle ?? 'Student',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          if (seasonName != null)
                            StatusChip(label: seasonName!, color: scheme.primary, dense: true),
                          if (standing != null)
                            GestureDetector(
                              // The chip is the only place the dashboard states a
                              // rank, so it goes to the page that explains it.
                              onTap: () => context.push('/more/leaderboard'),
                              child: StatusChip(
                                label: '#${standing!.rank} of ${standing!.players}',
                                color: accents.xp,
                                icon: CupertinoIcons.rosette,
                                dense: true,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _Metric(
                  icon: CupertinoIcons.star_fill,
                  color: accents.xp,
                  value: NumberFormat.compact().format(stats.totalXP.round()),
                  numericValue: stats.totalXP,
                  format: (double v) => NumberFormat.compact().format(v.round()),
                  label: 'Season XP',
                  onTap: () => showLevelSheet(context, stats),
                ),
                _MetricDivider(color: scheme.outlineVariant),
                _Metric(
                  icon: CupertinoIcons.flame_fill,
                  color: accents.streak,
                  value: '${stats.streak}',
                  numericValue: stats.streak.toDouble(),
                  label: 'Day streak',
                  onTap: onStreakTap,
                ),
                _MetricDivider(color: scheme.outlineVariant),
                _Metric(
                  icon: CupertinoIcons.checkmark_seal_fill,
                  color: accents.success,
                  value: NumberFormat.compact().format(stats.points.round()),
                  numericValue: stats.points,
                  format: (double v) => NumberFormat.compact().format(v.round()),
                  label: 'Points',
                  onTap: onPointsTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The level number inside a progress ring — the one place the hero spends a
/// strong visual accent, so it reads before anything else on the screen.
class _LevelRing extends StatelessWidget {
  const _LevelRing({required this.level, required this.progress, required this.onTap});

  final int level;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double size = 72;

    return Semantics(
      button: true,
      label: 'Level $level. Opens your level details.',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedLevelRing(
          progress: progress,
          size: size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$level',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'LEVEL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.numericValue,
    this.format,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final double? numericValue;
  final String Function(double)? format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? valueStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    final Widget valueText = numericValue == null
        ? Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          )
        : AnimatedCount(value: numericValue!, style: valueStyle, format: format);

    final Widget column = Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(child: valueText),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );

    if (onTap == null) return Expanded(child: column);

    // Tappable without a visible border or background: the numbers are the
    // affordance, and an underline would read as a link in a metrics strip.
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label: $value',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: column,
          ),
        ),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 26, width: 1, color: color.withValues(alpha: 0.5));
  }
}

/// A claimable reward. Amber, because XP everywhere else in the app is amber.
class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.reward, required this.data});

  final _Reward reward;

  /// The whole payload, so tapping the card's body can open the sheet that
  /// explains this particular reward alongside the rest of the season's numbers.
  final DashboardData data;

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final XpClaimResult result = reward.isBonus
        ? await ref.read(claimXpControllerProvider.notifier).claimBonus()
        : await ref.read(claimXpControllerProvider.notifier).claimDaily();

    if (!context.mounted) return;
    showSnack(
      context,
      result.claimed
          ? '+${result.amount} XP claimed. Streak: ${result.streak} days.'
          : 'Nothing to claim right now.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Color amber = context.accents.xp;

    return Card(
      color: amber.withValues(alpha: 0.10),
      // The whole card opens the explanation; the Claim button inside it handles
      // its own tap, and InkWell lets that win without an extra gesture layer.
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showClaimSheet(context: context, data: data, isBonus: reward.isBonus),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
          children: <Widget>[
            PopIn(
              child: Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.gift_fill, size: 17, color: amber),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    reward.isBonus ? 'Bonus XP' : 'Daily streak reward',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    reward.isBonus
                        ? '+${reward.claim.amount} XP available right now'
                        : '+${reward.claim.amount} XP for keeping your streak',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              // The theme gives every FilledButton `Size.fromHeight(50)`, which
              // resolves to an infinite width. Inside a Row that is an invalid
              // constraint and throws during layout, so this button opts out of
              // the theme's minimum and sizes to its own content.
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: theme.textTheme.labelLarge,
              ),
              onPressed: () => _claim(context, ref),
              child: const Text('Claim'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Layout-shaped loading state. Blocks sit directly on the grouped background
/// rather than inside white cards, which is what made the previous skeleton
/// effectively invisible on a light theme.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const Skeleton(height: 180, radius: 14),
        const SizedBox(height: 12),
        const Skeleton(height: 62, radius: 14),
        const SizedBox(height: 28),
        const Skeleton(height: 14, width: 90),
        const SizedBox(height: 10),
        const Skeleton(height: 128, radius: 14),
        const SizedBox(height: 28),
        const Skeleton(height: 14, width: 120),
        const SizedBox(height: 10),
        const Skeleton(height: 96, radius: 14),
      ],
    );
  }
}

class _UpcomingExamRow extends StatelessWidget {
  const _UpcomingExamRow({required this.exam, required this.isFirst, required this.isLast});

  final UpcomingExam exam;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final ({String label, Color color, IconData icon}) status = switch (exam) {
      _ when exam.isCompleted => (
          label: 'Submitted',
          color: AppTheme.success,
          icon: CupertinoIcons.checkmark_circle_fill,
        ),
      _ when exam.isOpenNow => (
          label: 'Open',
          color: AppTheme.success,
          icon: CupertinoIcons.clock_fill,
        ),
      _ when exam.isUpcoming => (
          label: 'Upcoming',
          color: scheme.primary,
          icon: CupertinoIcons.clock,
        ),
      _ => (
          label: 'Closed',
          color: scheme.onSurfaceVariant,
          icon: CupertinoIcons.lock_fill,
        ),
    };

    final String? timing = switch (exam) {
      _ when exam.isOpenNow && exam.endsAt != null => 'Closes ${DateFormat.MMMd().add_jm().format(exam.endsAt!)}',
      _ when exam.isUpcoming && exam.startsAt != null => 'Opens ${DateFormat.MMMd().add_jm().format(exam.startsAt!)}',
      _ when exam.hasEnded && exam.endsAt != null => 'Ended ${DateFormat.MMMd().format(exam.endsAt!)}',
      _ => null,
    };

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      showChevron: true,
      onTap: () => context.push('/exams/${exam.id}'),
      leading: StatusChip(label: status.label, color: status.color, icon: status.icon, dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            exam.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (timing != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(timing, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 4),
          Text(
            '${exam.durationMinutes} min · ${exam.submittedParts}/${exam.partsCount} parts'
            '${exam.setTitle != null ? ' · ${exam.setTitle}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.assignment, required this.isFirst, required this.isLast});

  final AssignmentSummary assignment;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final bool overdue = assignment.isOverdue && !assignment.submitted;

    final ({Color color, IconData icon}) status = assignment.submitted
        ? (color: AppTheme.success, icon: CupertinoIcons.checkmark_circle_fill)
        : overdue
        ? (color: scheme.error, icon: CupertinoIcons.exclamationmark_circle_fill)
        : (color: scheme.onSurfaceVariant, icon: CupertinoIcons.doc_plaintext);

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(status.icon, size: 22, color: status.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            assignment.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: overdue ? scheme.error : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            assignment.dueLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: overdue ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
          if (assignment.grade != null) ...<Widget>[
            const SizedBox(height: 6),
            StatusChip(label: 'Grade: ${assignment.grade}', color: AppTheme.success, dense: true),
          ],
        ],
      ),
    );
  }
}

/// Streak summary plus the 90-day login heatmap, newest week on the right.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.dates, required this.streak, required this.longestStreak});

  final Set<String> dates;
  final int streak;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;

    final DateTime today = DateTime.now();
    // Start on the Monday 12 weeks back so every column is a full week.
    final DateTime start = today.subtract(Duration(days: today.weekday - 1 + 7 * 12));
    final DateFormat keyFormat = DateFormat('yyyy-MM-dd');

    final int activeDays = dates.where((String key) {
      final DateTime? parsed = DateTime.tryParse(key);
      return parsed != null && !parsed.isBefore(start) && !parsed.isAfter(today);
    }).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(CupertinoIcons.flame_fill, size: 18, color: accents.streak),
                const SizedBox(width: 6),
                Text('$streak-day streak', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 2),
            // Kept on its own line: paired with the title in one row it
            // overflows on a narrow phone or at a larger text scale.
            Text(
              'Best $longestStreak days · $activeDays days active in the last 13 weeks',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const int columns = 13;
                const double gap = 3;
                final double cell = ((constraints.maxWidth - gap * (columns - 1)) / columns).clamp(8.0, 20.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (int week = 0; week < columns; week++)
                      Column(
                        children: <Widget>[
                          for (int day = 0; day < 7; day++)
                            Builder(
                              builder: (BuildContext context) {
                                final DateTime date = start.add(Duration(days: week * 7 + day));
                                if (date.isAfter(today)) {
                                  return SizedBox(height: cell, width: cell);
                                }

                                final bool active = dates.contains(keyFormat.format(date));
                                return Container(
                                  height: cell,
                                  width: cell,
                                  margin: EdgeInsets.only(bottom: day == 6 ? 0 : gap),
                                  decoration: BoxDecoration(
                                    color: active ? scheme.primary : scheme.onSurface.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text(
                  DateFormat.MMM().format(start),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  'Today',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({required this.announcement, required this.isFirst, required this.isLast});

  final Announcement announcement;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      showChevron: announcement.link != null,
      onTap: announcement.link == null
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: announcement.link!));
              if (context.mounted) {
                showSnack(context, 'Link copied: ${announcement.link}');
              }
            },
      leading: Icon(CupertinoIcons.bell_fill, size: 20, color: scheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            announcement.title,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (announcement.sectionName != null || announcement.createdAtLabel != null) ...<Widget>[
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                if (announcement.sectionName != null)
                  Flexible(
                    child: Text(
                      announcement.sectionName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                    ),
                  ),
                if (announcement.sectionName != null && announcement.createdAtLabel != null)
                  Text(' · ', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                if (announcement.createdAtLabel != null)
                  Text(
                    announcement.createdAtLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
          if (announcement.description != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              announcement.description!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
            ),
          ],
          if (announcement.link != null) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(CupertinoIcons.link, size: 13, color: scheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    announcement.link!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.board});

  final SectionLeaderboard board;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!board.leaderboardEnabled) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const Icon(Icons.visibility_off_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The leaderboard for this section is currently hidden.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<LeaderboardUser> top = board.users.take(5).toList(growable: false);

    return GroupedList(
      children: <Widget>[
        for (int i = 0; i < top.length; i++)
          _LeaderboardRow(
            rank: i + 1,
            user: top[i],
            isFirst: i == 0,
            isLast: i == top.length - 1,
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.user,
    required this.isFirst,
    required this.isLast,
  });

  final int rank;
  final LeaderboardUser user;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      leading: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: user.isCurrentUser ? scheme.primary : scheme.onSurface.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$rank',
          style: theme.textTheme.labelSmall?.copyWith(
            color: user.isCurrentUser ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (user.streak > 0) ...<Widget>[
            Icon(CupertinoIcons.flame_fill, size: 14, color: AppTheme.streak),
            const SizedBox(width: 2),
            Text('${user.streak}', style: theme.textTheme.labelSmall),
            const SizedBox(width: 10),
          ],
          Text(
            '${user.xp.round()} XP',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: user.isCurrentUser ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            'Level ${user.level}',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
