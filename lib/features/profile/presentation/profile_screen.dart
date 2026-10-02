import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/lsi_mascot.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/state/auth_providers.dart';
import '../../dashboard/domain/dashboard_data.dart';
import '../../dashboard/state/dashboard_providers.dart';
import '../../leaderboard/domain/leaderboard_models.dart';
import '../../leaderboard/state/leaderboard_providers.dart';
import '../domain/xp_history.dart';
import '../state/profile_providers.dart';

/// Design-first student profile: identity + mascot, stats, standing,
/// streak protection, badges preview, XP ledger, account actions.
///
/// Data today: session (instant) + dashboard (streak/longest/points/level
/// progress) + leaderboard (rank) + xp-history (ledger). Backend later fills
/// badges, freeze inventory, avatar upload.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider).value;
    final AsyncValue<XpHistory> history = ref.watch(xpHistoryProvider);
    final AsyncValue<LeaderboardData> boards = ref.watch(leaderboardProvider);
    final AsyncValue<DashboardData> dash = ref.watch(dashboardProvider);
    final DashboardData? dashData = dash.value;
    final LeaderboardData? boardsData = boards.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(xpHistoryProvider);
              ref.invalidate(leaderboardProvider);
              ref.invalidate(dashboardProvider);
            },
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          const ProfileMenu(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(xpHistoryProvider);
          ref.invalidate(leaderboardProvider);
          ref.invalidate(dashboardProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _IdentityCard(
                user: user,
                dash: dashData,
                boards: boardsData,
              ),
            ),
            const SectionHeader(title: 'Stats', subtitle: 'This season at a glance'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StatsGrid(user: user, dash: dashData, boards: boardsData),
            ),
            if (boards.hasValue) ...<Widget>[
              const SectionHeader(title: 'Standing', subtitle: 'Where you sit per section'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Standing(boards: boards.value!),
              ),
            ],
            // XP history stays high so it renders in the first viewport
            // (student_pages_test asserts it without scrolling).
            const SectionHeader(title: 'XP history'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: history.when(
                loading: () => const GroupedList(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Skeleton(height: 96, radius: 10),
                    ),
                  ],
                ),
                error: (Object error, StackTrace _) => InlineNotice(
                  message: 'Could not load your XP history.',
                  tone: InlineNoticeTone.error,
                  onRetry: () => ref.invalidate(xpHistoryProvider),
                ),
                data: (XpHistory data) => _Ledger(data: data),
              ),
            ),
            const SectionHeader(title: 'Streak protection', subtitle: 'Freezes and restores'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProtectionCard(dash: dashData),
            ),
            const SectionHeader(title: 'Badges', subtitle: 'One per level · design preview'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _BadgesPreview(),
            ),
            const SectionHeader(title: 'Account'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AccountActions(user: user),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the student sits in each of their sections.
class _Standing extends StatelessWidget {
  const _Standing({required this.boards});

  final LeaderboardData boards;

  @override
  Widget build(BuildContext context) {
    final List<SectionLeaderboard> ranked = boards.boards
        .where((SectionLeaderboard b) => b.totalPlayers > 0 && b.userRank > 0)
        .toList(growable: false);

    if (ranked.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'You are not ranked in any section yet this season.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return GroupedList(
      children: <Widget>[
        for (int i = 0; i < ranked.length; i++)
          _StandingRow(board: ranked[i], isFirst: i == 0, isLast: i == ranked.length - 1),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.board, required this.isFirst, required this.isLast});

  final SectionLeaderboard board;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool topPercent = board.totalPlayers > 0 && board.userRank <= (board.totalPlayers / 10).ceil();

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      onTap: () => context.push('/more/leaderboard'),
      showChevron: true,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '#${board.userRank}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: topPercent ? context.accents.xp : scheme.onSurface,
            ),
          ),
          Text(
            'of ${board.totalPlayers}',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            board.sectionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 1),
          Text(
            board.leaderboardEnabled
                ? 'Season standings'
                : 'Hidden board · your rank is still tracked',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Header: avatar + mascot + level ring + chips.
///
/// Mascot mood reacts to streak so the design is testable now:
/// 0 -> sleeping, 1-6 -> happy, 7+ -> celebrating.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user, required this.dash, required this.boards});

  final AppUser? user;
  final DashboardData? dash;
  final LeaderboardData? boards;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String name = user?.name ?? 'Student';
    final int streak = user?.currentStreak ?? dash?.userStats.streak ?? 0;
    final int level = user?.level ?? dash?.userStats.level ?? 1;
    final double progress = dash?.userStats.levelProgress ?? 0.12;
    final LsiMascotMood mood = streak <= 0
        ? LsiMascotMood.sleeping
        : streak >= 7
            ? LsiMascotMood.celebrating
            : LsiMascotMood.happy;

    String? rankLabel;
    if (boards != null) {
      for (final SectionLeaderboard b in boards!.boards) {
        if (b.totalPlayers > 0 && b.userRank > 0) {
          rankLabel = '#${b.userRank} of ${b.totalPlayers}';
          break;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Avatar with level ring.
                SizedBox(
                  height: 72, width: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox(
                        height: 72, width: 72,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      Container(
                        height: 58, width: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                        child: Text(
                          user?.initials ?? '?',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
                          child: Text('Lv $level', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: <Widget>[
                          if (user?.publicId.isNotEmpty ?? false)
                            StatusChip(label: user!.publicId, color: scheme.onSurfaceVariant, dense: true),
                          if (dash?.activeSeasonName != null)
                            StatusChip(label: dash!.activeSeasonName!, color: scheme.primary, dense: true),
                          if (rankLabel != null)
                            StatusChip(label: rankLabel, color: context.accents.xp, icon: CupertinoIcons.rosette, dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                LsiMascot(mood: mood, size: 56),
              ],
            ),
            const SizedBox(height: 14),
            // Level progress line (design uses dash when available).
            if (dash != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: dash!.userStats.levelProgress.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${dash!.userStats.xpToNextLevel.round()} XP to Level ${dash!.userStats.nextLevel} · ${dash!.userStats.totalXP.round()} XP this season',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              )
            else
              Text(
                'Level $level · ${(user?.exp ?? 0).round()} XP this season',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditPreview(context),
                    icon: const Icon(CupertinoIcons.pencil, size: 15),
                    label: const Text('Edit profile', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/more/leaderboard'),
                    icon: const Icon(CupertinoIcons.rosette, size: 15),
                    label: const Text('View rank', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPreview(BuildContext context) {
    AppSheet.show<void>(
      context: context,
      title: 'Edit profile',
      subtitle: 'Design preview',
      icon: CupertinoIcons.pencil,
      children: <Widget>[
        const MascotMessage(
          mood: LsiMascotMood.studying,
          title: 'Avatar upload comes later',
          subtitle: 'Backend will add POST /users/me/avatar. For now pick a color + mascot pose stored locally.',
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            for (final LsiMascotMood m in LsiMascotMood.values.take(4))
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(children: <Widget>[LsiMascot(mood: m, size: 52), const SizedBox(height: 4), Text(m.name, style: const TextStyle(fontSize: 10))]))),
          ],
        ),
        const SizedBox(height: 14),
        const SheetNote(message: 'Name, email and public ID stay read-only — they come from the school record. Nickname + avatar are the editable bits.'),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.user, required this.dash, required this.boards});
  final AppUser? user;
  final DashboardData? dash;
  final LeaderboardData? boards;

  @override
  Widget build(BuildContext context) {
    final int xp = (dash?.userStats.totalXP ?? user?.exp ?? 0).round();
    final int level = dash?.userStats.level ?? user?.level ?? 1;
    final int streak = dash?.userStats.streak ?? user?.currentStreak ?? 0;
    final int longest = dash?.userStats.longestStreak ?? 21;
    final int points = (dash?.userStats.points ?? 340).round();
    String rank = '—';
    if (boards != null) {
      for (final SectionLeaderboard b in boards!.boards) {
        if (b.userRank > 0) {
          rank = '#${b.userRank}';
          break;
        }
      }
    }

    final List<({IconData icon, Color color, String value, String label})> items = <({IconData icon, Color color, String value, String label})>[
      (icon: CupertinoIcons.star_fill, color: context.accents.xp, value: '$xp', label: 'Season XP'),
      (icon: CupertinoIcons.rosette, color: Theme.of(context).colorScheme.primary, value: '$level', label: 'Level'),
      (icon: CupertinoIcons.flame_fill, color: context.accents.streak, value: '$streak', label: 'Day streak'),
      (icon: CupertinoIcons.bolt_fill, color: context.accents.streak, value: '$longest', label: 'Longest'),
      (icon: CupertinoIcons.checkmark_seal_fill, color: context.accents.success, value: '$points', label: 'Points'),
      (icon: CupertinoIcons.chart_bar_alt_fill, color: Theme.of(context).colorScheme.primary, value: rank, label: 'Best rank'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisExtent: 74),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int i) {
            final item = items[i];
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[Icon(item.icon, size: 13, color: item.color), const SizedBox(width: 4), Text(item.value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
                const SizedBox(height: 2),
                Text(item.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.dash});
  final DashboardData? dash;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StreakRestoreInfo r = dash?.streakRestore ?? const StreakRestoreInfo();
    final bool broken = r.isBroken;

    return Card(
      color: (broken ? theme.colorScheme.error : context.accents.streak).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: <Widget>[
            MascotMessage(
              mood: broken ? LsiMascotMood.sad : LsiMascotMood.happy,
              title: broken ? 'Streak broke — restore available' : '1 Freeze available · Restore costs ${r.restoreCost} pts',
              subtitle: broken ? r.deadlineLabel : 'A Freeze auto-saves one missed day. Without one, restore manually within 48h.',
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppSheet.show<void>(
                      context: context,
                      title: 'Streak Freeze',
                      subtitle: 'Design preview',
                      icon: CupertinoIcons.snow,
                      children: const <Widget>[
                        MascotMessage(mood: LsiMascotMood.sleeping, title: 'Freeze equipped', subtitle: 'Backend later: GET /streak/freeze inventory + POST /streak/freeze/equip. Design shows 1 active, next freeze earns at 14-day streak.'),
                        SizedBox(height: 12),
                        SheetNote(message: 'Freeze triggers automatically on the first missed day. Restore is the manual backup.'),
                      ],
                    ),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    child: const Text('Freeze', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/dashboard'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                    child: Text(broken ? 'Restore now' : 'How restore works', style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesPreview extends StatelessWidget {
  const _BadgesPreview();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Design placeholder: 6 slots, first 2 unlocked.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const MascotMessage(mood: LsiMascotMood.celebrating, title: 'Next badge at Level 26', subtitle: 'Earn 20 more XP to become eligible. Badges are one per level.'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 92),
              itemCount: 6,
              itemBuilder: (BuildContext context, int i) {
                final bool unlocked = i < 2;
                return Container(
                  decoration: BoxDecoration(
                    color: unlocked ? context.accents.xp.withValues(alpha: 0.12) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(unlocked ? CupertinoIcons.rosette : CupertinoIcons.lock_fill, size: 22, color: unlocked ? context.accents.xp : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 6),
                      Text(unlocked ? 'Level ${20 + i}' : 'Locked', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const SheetNote(message: 'Backend has no badge list endpoint yet — this grid is mock data. Real art from luav6 goes here.'),
          ],
        ),
      ),
    );
  }
}

class _AccountActions extends ConsumerWidget {
  const _AccountActions({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupedList(
      children: <Widget>[
        GroupedRow(
          isFirst: true,
          leading: const Icon(CupertinoIcons.gear, size: 20),
          showChevron: true,
          onTap: () => context.push('/more/settings'),
          child: Text('Settings', style: Theme.of(context).textTheme.bodyLarge),
        ),
        GroupedRow(
          leading: const Icon(CupertinoIcons.eye_slash, size: 20),
          showChevron: true,
          onTap: () => AppSheet.show<void>(
            context: context,
            title: 'Leaderboard privacy',
            subtitle: 'Design preview',
            icon: CupertinoIcons.eye_slash,
            children: const <Widget>[
              SheetNote(message: 'Backend: POST /leaderboard/toggle-blur exists in fake. Wire a Switch here bound to viewerIsBlurred. Hidden name shows as “Anonymous”.'),
            ],
          ),
          child: Text('Leaderboard privacy', style: Theme.of(context).textTheme.bodyLarge),
        ),
        GroupedRow(
          isLast: true,
          leading: Icon(CupertinoIcons.square_arrow_left, size: 20, color: Theme.of(context).colorScheme.error),
          onTap: () async {
            await ref.read(sessionProvider.notifier).signOut();
            if (context.mounted) context.go('/login');
          },
          child: Text('Sign out', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.data});

  final XpHistory data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: MascotMessage(mood: LsiMascotMood.studying, title: 'No XP yet', subtitle: 'Claim your daily streak or submit work to start the ledger.'),
        ),
      );
    }

    return GroupedList(
      children: <Widget>[
        for (int i = 0; i < data.entries.length; i++)
          _LedgerRow(
            entry: data.entries[i],
            isFirst: i == 0,
            isLast: i == data.entries.length - 1,
          ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.isFirst, required this.isLast});

  final XpEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;
    final Color tone = entry.isCredit ? accents.xp : scheme.error;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      leading: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(
          entry.isCredit ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
          size: 14,
          color: tone,
        ),
      ),
      trailing: Text(
        entry.amountLabel,
        style: theme.textTheme.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (entry.description != null)
            Text(
              entry.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 3),
          Text(
            <String>[
              ?entry.sectionName,
              if (entry.createdAtLabel.isNotEmpty) entry.createdAtLabel,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
