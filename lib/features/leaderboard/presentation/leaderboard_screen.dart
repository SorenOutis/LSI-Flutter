import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common.dart';
import '../domain/leaderboard_models.dart';
import '../state/leaderboard_providers.dart';

/// Section standings for the current season: a podium for the top three, then
/// everyone else, with the student's own row marked.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LeaderboardData> leaderboard = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(leaderboardProvider),
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          const ProfileMenu(),
        ],
      ),
      body: leaderboard.when(
        loading: () => const SkeletonList(count: 4),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(leaderboardProvider),
        ),
        data: (LeaderboardData data) {
          if (data.isEmpty) {
            return const EmptyView(
              title: 'No standings yet',
              message: 'Once you are enrolled in a section with an active season, its rankings will appear here.',
              icon: CupertinoIcons.rosette,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leaderboardProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                if (data.seasonName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Row(
                      children: <Widget>[
                        StatusChip(
                          label: data.seasonName!,
                          color: Theme.of(context).colorScheme.primary,
                          icon: CupertinoIcons.rosette,
                          dense: true,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Season standings',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final SectionLeaderboard board in data.boards) ...<Widget>[
                  SectionHeader(
                    title: board.sectionName,
                    subtitle: board.leaderboardEnabled && board.totalPlayers > 0
                        ? 'You are #${board.userRank} of ${board.totalPlayers}'
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _Board(board: board),
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

class _Board extends StatelessWidget {
  const _Board({required this.board});

  final SectionLeaderboard board;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

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
                  'The leaderboard for this section is currently hidden. Your rank is still being tracked.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<LeaderboardUser> top = board.users.take(3).toList(growable: false);
    final List<LeaderboardUser> rest = board.users.skip(3).toList(growable: false);

    return Column(
      children: <Widget>[
        if (top.isNotEmpty) _Podium(top: top),
        if (rest.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          GroupedList(
            children: <Widget>[
              for (int i = 0; i < rest.length; i++)
                _RankRow(
                  rank: i + 4,
                  user: rest[i],
                  isFirst: i == 0,
                  isLast: i == rest.length - 1,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The top three, with the leader raised. Avatars are initials — the API has no
/// image for most students, so an empty grey circle would be worse.
class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<LeaderboardUser> top;

  @override
  Widget build(BuildContext context) {
    final LeaderboardUser? first = top.isNotEmpty ? top[0] : null;
    final LeaderboardUser? second = top.length > 1 ? top[1] : null;
    final LeaderboardUser? third = top.length > 2 ? top[2] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: _Place(rank: 2, user: second)),
            Expanded(child: _Place(rank: 1, user: first, featured: true)),
            Expanded(child: _Place(rank: 3, user: third)),
          ],
        ),
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({required this.rank, required this.user, this.featured = false});

  final int rank;
  final LeaderboardUser? user;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;
    final double size = featured ? 64 : 52;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (featured)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(Icons.emoji_events_rounded, size: 18, color: accents.xp),
          ),
        Container(
          height: size,
          width: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: user!.isCurrentUser
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: featured ? 0.10 : 0.06),
            shape: BoxShape.circle,
            border: featured ? Border.all(color: accents.xp.withValues(alpha: 0.5), width: 2) : null,
          ),
          child: Text(
            _initials(user!.name),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: user!.isCurrentUser ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user!.name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: user!.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
            color: user!.isCurrentUser ? scheme.primary : scheme.onSurface,
          ),
        ),
        Text(
          '#$rank · ${user!.xp.round()} XP',
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.user, required this.isFirst, required this.isLast});

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
