import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// Full-screen loading state for a first load, with an optional message.
///
/// Wrapped in a scroll view so a long message or a large text scale cannot
/// overflow, which a bare Center+Column did.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoSpinner(),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Material spinner is the most visibly un-Apple element in a Material app;
/// a thin arc matches what iOS shows.
class CupertinoSpinner extends StatefulWidget {
  const CupertinoSpinner({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  State<CupertinoSpinner> createState() => _CupertinoSpinnerState();
}

class _CupertinoSpinnerState extends State<CupertinoSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _ArcPainter(
            color: widget.color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;

    final Rect rect = Offset.zero & size;
    const double start = -1.5708; // 12 o'clock
    const double sweep = 4.18879; // 240 degrees

    paint.color = color.withValues(alpha: 0.15);
    canvas.drawArc(rect, start, 6.28318, false, paint);

    paint.color = color;
    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}

/// A shimmering placeholder block, used in place of a bare spinner once a
/// screen's shape is known.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool light = scheme.brightness == Brightness.light;
    final Color base = light ? const Color(0xFFE5E5EA) : scheme.surfaceContainerHighest;
    final Color highlight = light ? const Color(0xFFF2F2F7) : scheme.surfaceContainerHigh;

    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(widget.radius)),
      );
    }

    // Sweep shimmer: a highlight band travelling left→right, instead of the
    // old opacity pulse which read as a flicker on the grouped background.
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, highlight, base],
            stops: [
              (_controller.value * 2 - 0.6).clamp(0.0, 1.0),
              (_controller.value * 2 - 0.3).clamp(0.0, 1.0),
              (_controller.value * 2).clamp(0.0, 1.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card-shaped skeleton, the common unit for list loading states.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.showLeading = true});

  final int lines;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLeading) ...[
            const Skeleton(width: 40, height: 40, radius: 10),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < lines; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Skeleton(
                    height: i == 0 ? 16 : 12,
                    width: i == 0 ? 180 : (i.isEven ? double.infinity : 220),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A stack of [SkeletonCard]s for a list that is still loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.listPadding});

  final int count;
  final EdgeInsets? listPadding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: listPadding ?? const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: count,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) => const SkeletonCard(),
    );
  }
}

/// Retryable error state. Renders the message an [ApiException] already
/// produced, so no screen has to invent its own error copy.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, this.icon = Icons.cloud_off_rounded});

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: icon,
      title: 'Something went wrong',
      message: message,
      action: onRetry == null
          ? null
          : SizedBox(
              width: 180,
              child: FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
    );
  }
}

/// Centered empty state.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.message, this.icon = Icons.inbox_rounded, this.action});

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(icon: icon, title: title, message: message, action: action);
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: scheme.onSurface.withValues(alpha: 0.35)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 20), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact error/empty banner for use *inside* a list or card, where a
/// full-screen state would be wrong.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = InlineNoticeTone.neutral,
    this.onRetry,
  });

  final String message;
  final IconData icon;
  final InlineNoticeTone tone;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Color accent = switch (tone) {
      InlineNoticeTone.neutral => scheme.onSurfaceVariant,
      InlineNoticeTone.error => scheme.error,
      InlineNoticeTone.warning => const Color(0xFFF59E0B),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: accent, height: 1.35),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum InlineNoticeTone { neutral, error, warning }

/// Section header used across the dashboard and detail screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      // Indented to align with the card gutter, as in a grouped table header.
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uppercase and tracked-out, matching an iOS section header.
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                    fontSize: 12,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small coloured pill for a status or count.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon, this.dense = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row inside a grouped card, with an optional trailing chevron.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.child,
    this.onTap,
    this.leading,
    this.trailing,
    this.showChevron = false,
    this.isFirst = false,
    this.isLast = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Widget? leading;

  /// Sits between [child] and the chevron. Distinct from `trailing` on iOS,
  /// where the chevron is a separate affordance rather than the row's trailing
  /// content.
  final Widget? trailing;
  final bool showChevron;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double corner = 14;

    return Column(
      children: [
        if (!isFirst)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(corner) : Radius.zero,
              bottom: isLast ? const Radius.circular(corner) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(child: child),
                  if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                  if (showChevron)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 15,
                        color: scheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded container that groups rows, matching an iOS inset grouped table.
///
/// Takes any children; wrap each in a [GroupedRow] to get the hairline
/// separators and corner-aware ink.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Show a message in a floating snackbar.
void showSnack(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;

  final ColorScheme scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : null,
      ),
    );
}
