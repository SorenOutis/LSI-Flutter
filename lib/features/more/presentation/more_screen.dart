import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/state/auth_providers.dart';

/// The fourth tab: everything that does not earn a permanent slot in the bar.
///
/// Grouped by what a row is for rather than alphabetically: what the student is
/// learning, then the app's own settings, then what still has to happen on the
/// website. Destinations the API supports but the app has not built yet are
/// listed with a "Soon" marker instead of being hidden — a student looking for
/// Courses should find out it is coming, not conclude the app is broken.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        actions: const <Widget>[ProfileMenu()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: FadeSlideIn(child: _ProfileHeader(user: user)),
          ),
          const SectionHeader(title: 'Learning'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FadeSlideIn(
              delay: AppMotion.stagger(1),
              scale: false,
              child: GroupedList(
                children: <Widget>[
                  _MenuRow(
                    isFirst: true,
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    tone: context.scheme.primary,
                    title: 'Grades',
                    subtitle: 'Subject averages and period grades',
                    onTap: () => context.push('/more/grades'),
                  ),
                  _MenuRow(
                    icon: CupertinoIcons.doc_plaintext,
                    tone: context.accents.xp,
                    title: 'Assignments',
                    subtitle: 'What is still to hand in, and what came back',
                    onTap: () => context.push('/more/assignments'),
                  ),
                  _MenuRow(
                    icon: CupertinoIcons.time,
                    tone: context.accents.success,
                    title: 'Activity',
                    subtitle: 'Deadlines coming up and your recent XP',
                    onTap: () => context.push('/more/activity'),
                  ),
                  _MenuRow(
                    icon: CupertinoIcons.rosette,
                    tone: context.accents.streak,
                    title: 'Leaderboard',
                    subtitle: 'How your section is ranking this season',
                    onTap: () => context.push('/more/leaderboard'),
                  ),
                  _MenuRow(
                    isLast: true,
                    icon: CupertinoIcons.chat_bubble_text,
                    tone: context.scheme.primary,
                    title: 'Chats',
                    subtitle: 'Pick up a conversation with Echo',
                    onTap: () => context.push('/more/chats'),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'App'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FadeSlideIn(
              delay: AppMotion.stagger(2),
              scale: false,
              child: GroupedList(
                children: <Widget>[
                  _MenuRow(
                    isFirst: true,
                    icon: CupertinoIcons.gear,
                    title: 'Settings',
                    subtitle: 'Appearance, privacy and account',
                    onTap: () => context.push('/more/settings'),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: 'Not on mobile yet',
            subtitle: 'These still live on the website',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FadeSlideIn(
              delay: AppMotion.stagger(3),
              scale: false,
              child: GroupedList(
                children: <Widget>[
                  _MenuRow(
                    isFirst: true,
                    icon: CupertinoIcons.book,
                    title: 'Courses',
                    subtitle: 'Lessons and lesson quizzes',
                    soon: true,
                  ),
                  _MenuRow(
                    icon: CupertinoIcons.sparkles,
                    title: 'Community',
                    subtitle: 'Anonymous shoutouts from your school',
                    soon: true,
                  ),
                  _MenuRow(
                    isLast: true,
                    icon: CupertinoIcons.game_controller,
                    title: 'Games',
                    subtitle: 'Tower defense and the arcade',
                    soon: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: () => context.push('/more/profile'),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                height: 52,
                width: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Text(
                  user?.initials ?? '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      user?.name ?? 'Student',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level ${user?.level ?? 1} · ${(user?.exp ?? 0).round()} XP this season',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_forward, size: 15, color: scheme.onSurface.withValues(alpha: 0.25)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tone,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.soon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? tone;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = tone ?? scheme.onSurfaceVariant;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      onTap: onTap,
      showChevron: onTap != null,
      leading: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: soon ? 0.07 : 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: accent.withValues(alpha: soon ? 0.5 : 1)),
      ),
      trailing: soon
          ? const StatusChip(label: 'Soon', color: Color(0xFF8E8E93), dense: true)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: soon ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
