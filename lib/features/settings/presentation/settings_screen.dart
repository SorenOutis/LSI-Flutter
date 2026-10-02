import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/state/auth_providers.dart';
import '../domain/app_settings.dart';
import '../state/settings_providers.dart';
import 'sheets/change_password_sheet.dart';

/// Everything the student can change about the app or their account.
///
/// Grouped the way a settings list is read — by subject, not by screen — and
/// every row leads somewhere real: appearance applies immediately, privacy writes
/// to the account, and the account group ends the session. Rows the API does not
/// support are absent rather than shown disabled, because a dead switch is worse
/// than a missing one: it implies the change is stored somewhere when it is not.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider).value;
    final AppSettings settings = ref.watch(settingsProvider);
    final bool blurring = ref.watch(leaderboardBlurControllerProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _AccountCard(user: user),
          ),

          const SectionHeader(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GroupedList(
              children: <Widget>[
                _AppearanceRow(
                  isFirst: true,
                  isLast: true,
                  selected: settings.option,
                  onSelected: (ThemeModeOption mode) =>
                      unawaited(ref.read(settingsProvider.notifier).setThemeMode(mode)),
                ),
              ],
            ),
          ),

          const SectionHeader(
            title: 'Account & security',
            subtitle: 'Password lives here · email comes from your school record',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GroupedList(
              children: <Widget>[
                GroupedRow(
                  isFirst: true,
                  leading: const Icon(CupertinoIcons.lock_fill, size: 20),
                  showChevron: true,
                  onTap: () => showChangePasswordSheet(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Change password', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 1),
                      Text(
                        'Needs current + new · 8 chars, letter + number',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                GroupedRow(
                  isLast: true,
                  leading: const Icon(CupertinoIcons.mail, size: 20),
                  trailing: StatusChip(
                    label: 'School record',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    dense: true,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Email', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 1),
                      Text(
                        user?.email ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SectionHeader(
            title: 'Privacy',
            subtitle: 'Leaderboard privacy applies to every section you are in',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GroupedList(
              children: <Widget>[
                _BlurRow(
                  isFirst: true,
                  isLast: false,
                  blurring: blurring,
                  onChanged: () => _toggleBlur(context, ref),
                ),
                GroupedRow(
                  isLast: true,
                  leading: const Icon(CupertinoIcons.eye, size: 20),
                  showChevron: true,
                  onTap: () => AppSheet.show<void>(
                    context: context,
                    title: 'What blurred looks like',
                    subtitle: 'Design preview',
                    icon: CupertinoIcons.eye_slash,
                    children: <Widget>[
                      SheetNote(
                        message: blurring
                            ? 'On: your rows read “J•• •••” with your rank and XP intact. Teachers still see the full name.'
                            : 'Off: your full name “${user?.name ?? 'Juan Dela Cruz'}” is visible. Flip the switch above to preview blurred.',
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Preview blurred name', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 1),
                      Text(
                        blurring ? 'Currently hidden as initials' : 'Currently showing full name',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SectionHeader(
            title: 'Notifications',
            subtitle: 'On this device only · no backend yet',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GroupedList(
              children: <Widget>[
                _NotifRow(
                  isFirst: true,
                  icon: CupertinoIcons.doc_plaintext,
                  title: 'Assignment deadlines',
                  subtitle: 'Due-tomorrow and overdue nudges',
                  value: settings.notifAssignments,
                  onChanged: (bool v) => unawaited(ref.read(settingsProvider.notifier).setNotifAssignments(v)),
                ),
                _NotifRow(
                  icon: CupertinoIcons.chart_bar_alt_fill,
                  title: 'Grades posted',
                  subtitle: 'When a teacher records your grade',
                  value: settings.notifGrades,
                  onChanged: (bool v) => unawaited(ref.read(settingsProvider.notifier).setNotifGrades(v)),
                ),
                _NotifRow(
                  isLast: true,
                  icon: CupertinoIcons.flame_fill,
                  title: 'Streak reminders',
                  subtitle: 'Evening nudge before the day ends',
                  value: settings.notifStreak,
                  onChanged: (bool v) => unawaited(ref.read(settingsProvider.notifier).setNotifStreak(v)),
                ),
              ],
            ),
          ),

          const SectionHeader(title: 'Data'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _DataNote(),
          ),

          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SignOutButton(onPressed: () => _confirmSignOut(context, ref)),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlur(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(leaderboardBlurControllerProvider.notifier).toggle();
    } catch (_) {
      if (!context.mounted) return;
      showSnack(context, 'Could not update your privacy setting.', isError: true);
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your email and password to sign back in.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

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
                height: 48,
                width: 48,
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
                      user?.email ?? '',
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

/// Appearance as a segmented control rather than a row that pushes another
/// screen: there are exactly three choices, and showing all three at once makes
/// the difference between "System" and "Dark" obvious without navigating.
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.isFirst,
    required this.isLast,
    required this.selected,
    required this.onSelected,
  });

  final bool isFirst;
  final bool isLast;
  final ThemeModeOption selected;
  final ValueChanged<ThemeModeOption> onSelected;

  static const Map<ThemeModeOption, IconData> _icons = <ThemeModeOption, IconData>{
    ThemeModeOption.system: CupertinoIcons.device_phone_portrait,
    ThemeModeOption.light: CupertinoIcons.sun_max,
    ThemeModeOption.dark: CupertinoIcons.moon,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Theme', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(
            selected == ThemeModeOption.system ? 'Follows your device' : 'Always ${selected.label.toLowerCase()}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // SizedBox rather than a Row of Expanded buttons: the theme's
          // FilledButton minimum size is infinite in width, which cannot be
          // laid out inside a Row.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeModeOption>(
              segments: <ButtonSegment<ThemeModeOption>>[
                for (final ThemeModeOption option in ThemeModeOption.values)
                  ButtonSegment<ThemeModeOption>(
                    value: option,
                    icon: Icon(_icons[option], size: 15),
                    label: Text(option.label),
                  ),
              ],
              selected: <ThemeModeOption>{selected},
              showSelectedIcon: false,
              onSelectionChanged: (Set<ThemeModeOption> value) => onSelected(value.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll<TextStyle?>(theme.textTheme.labelMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurRow extends StatelessWidget {
  const _BlurRow({
    required this.isFirst,
    required this.isLast,
    required this.blurring,
    required this.onChanged,
  });

  final bool isFirst;
  final bool isLast;
  final bool blurring;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      trailing: Switch(value: blurring, onChanged: (_) => onChanged()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Hide my name on leaderboards', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text(
            blurring
                ? 'Your name appears as a blurred initial on every section board.'
                : 'Your full name is visible to everyone in your sections.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Where the numbers on screen come from, stated plainly.
///
/// A settings page that quietly invents capabilities is how a demo becomes a
/// product that does not work; this says what is live and what is not.
class _DataNote extends StatelessWidget {
  const _DataNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(CupertinoIcons.info_circle, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'About this build',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Grades, assignments, exams and standings are read live from the school API. '
              'Courses, the community feed and the games are still web-only.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      trailing: Switch(value: value, onChanged: onChanged),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(CupertinoIcons.power, size: 17),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.error,
          side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
          // The theme's filled-button height does not apply here, but the width
          // constraint is still infinite; SizedBox is what makes it stretch.
          minimumSize: const Size.fromHeight(50),
        ),
      ),
    );
  }
}