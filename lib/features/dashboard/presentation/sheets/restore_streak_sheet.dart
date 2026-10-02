import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/lsi_mascot.dart';
import '../../domain/dashboard_data.dart';
import '../../state/dashboard_providers.dart';

/// Design-first restore flow. No backend yet — confirm simulates success.
///
/// Flow: banner/row tap -> this sheet -> confirm -> success state ->
/// dashboard refresh. Backend later: `POST /streak/restore`.
Future<void> showRestoreStreakSheet(BuildContext context, WidgetRef ref, DashboardData data) {
  return AppSheet.show<void>(
    context: context,
    title: 'Restore your streak?',
    subtitle: 'Bring back the flame',
    icon: CupertinoIcons.flame_fill,
    children: <Widget>[_RestoreBody(data: data)],
  );
}

/// Standalone preview entry so you can test the design even while the
/// fake streak is healthy. Remove `preview=true` once backend sends isBroken.
class RestorePreviewCard extends ConsumerWidget {
  const RestorePreviewCard({super.key, required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StreakRestoreInfo r = data.streakRestore;
    if (r.isBroken) return _BrokenRestoreBanner(data: data);
    // Design preview while healthy: subtle protection card.
    // Column layout (no horizontal Row) so it can never overflow on
    // narrow phones or at larger text scales — the dashboard test
    // catches a 2px Row overflow as a full-screen blank.
    return Card(
      color: context.accents.streak.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showRestoreStreakSheet(context, ref, data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  LsiMascot(
                    mood: data.userStats.streak > 0 ? LsiMascotMood.happy : LsiMascotMood.sleeping,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${data.userStats.streak}-day protected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          'Preview restore · tap to open',
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12),
                  ),
                  onPressed: () => showRestoreStreakSheet(context, ref, data),
                  child: const Text('Preview restore design'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrokenRestoreBanner extends ConsumerWidget {
  const _BrokenRestoreBanner({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final StreakRestoreInfo r = data.streakRestore;
    return Card(
      color: theme.colorScheme.error.withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showRestoreStreakSheet(context, ref, data),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const LsiMascot(mood: LsiMascotMood.sad, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Your ${r.previousStreak}-day streak broke', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w700)),
                        Text(r.deadlineLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: EdgeInsets.zero),
                  onPressed: () => showRestoreStreakSheet(context, ref, data),
                  child: const Text('Restore streak'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreBody extends ConsumerStatefulWidget {
  const _RestoreBody({required this.data});
  final DashboardData data;

  @override
  ConsumerState<_RestoreBody> createState() => _RestoreBodyState();
}

class _RestoreBodyState extends ConsumerState<_RestoreBody> {
  bool _busy = false;
  bool _done = false;

  StreakRestoreInfo get r => widget.data.streakRestore;
  // Design defaults when backend sends nothing yet.
  int get _prev => r.previousStreak > 0 ? r.previousStreak : widget.data.userStats.streak > 0 ? widget.data.userStats.streak : 7;
  int get _cost => r.restoreCost;
  int get _balance => r.pointsBalance > 0 ? r.pointsBalance : widget.data.userStats.points.round();

  Future<void> _confirm() async {
    setState(() => _busy = true);
    // Simulate network. Backend later: ref.read(dashboardRepositoryProvider).restoreStreak()
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (_done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Center(child: LsiMascot(mood: LsiMascotMood.celebrating, size: 88)),
          const SizedBox(height: 12),
          Center(child: Text('Streak restored!', style: theme.textTheme.titleLarge)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'You are back at $_prev days. Earn XP today to keep it going.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              Navigator.of(context).pop();
              showSnack(context, 'Streak restored: $_prev days. (design preview)');
            },
            child: const Text('Nice!'),
          ),
        ],
      );
    }

    final bool afford = _balance >= _cost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MascotMessage(
          mood: afford ? LsiMascotMood.worried : LsiMascotMood.sad,
          title: 'You lost your $_prev-day streak ${r.breakLabel}',
          subtitle: 'Restore brings the flame back as if you never missed. Your calendar keeps the gap marked.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: <Widget>[
              _CostRow(icon: CupertinoIcons.flame_fill, color: context.accents.streak, label: 'Streak to restore', value: '$_prev days'),
              const SizedBox(height: 10),
              _CostRow(icon: CupertinoIcons.checkmark_seal_fill, color: context.accents.success, label: 'Cost', value: '$_cost points'),
              const SizedBox(height: 10),
              _CostRow(icon: CupertinoIcons.creditcard_fill, color: scheme.primary, label: 'Your balance', value: '$_balance pts'),
              const Divider(height: 20),
              Row(
                children: <Widget>[
                  Icon(CupertinoIcons.time, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r.deadlineLabel, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Icon(CupertinoIcons.bolt_fill, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text('One restore per break · longest streak is kept', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!afford)
          InlineNotice(message: 'Not enough points. You need $_cost but have $_balance. Earn points from graded work first.', tone: InlineNoticeTone.warning),
        if (r.freezeAvailable)
          const SheetNote(message: 'You have a Streak Freeze available — it would have saved this automatically. Equip one next time from Profile.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _busy
              ? null
              : afford
                  ? _confirm
                  : null,
          icon: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(CupertinoIcons.flame_fill, size: 18),
          label: Text(_busy ? 'Restoring…' : 'Restore for $_cost points'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Let it go — start fresh')),
        const SheetNote(message: 'Design preview: no points are deducted yet. Backend will wire POST /streak/restore later.'),
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          height: 30, width: 30,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
