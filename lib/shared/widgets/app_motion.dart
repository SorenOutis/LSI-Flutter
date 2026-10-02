import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Central motion language for the app.
///
/// The visual design already has a clear voice (iOS-grouped surfaces, Inter
/// with negative tracking, semantic amber/red/green). What it lacked was a
/// matching motion voice: screens popped in, numbers jumped, chat bubbles
/// appeared instantly.
///
/// Scale used everywhere:
///
/// * **fast (150ms)** — press feedback, icon toggles, chip changes.
/// * **medium (250ms)** — entrances, sheet children, bubble arrivals.
/// * **slow (400ms)** — hero numbers, level ring sweep, celebrations.
/// * Curves are always an ease-out cubic or a spring — nothing linear except
///   the spinner, which is a continuous rotation.
///
/// All entrance widgets respect `MediaQuery.disableAnimations`: when the OS
/// asks for reduced motion they render the final state immediately.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration entrance = Duration(milliseconds: 500);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  /// Stagger step for lists — 40ms per item, capped so a long list does not
  /// keep animating after the user has started reading.
  static Duration stagger(int index, {int capMs = 300}) {
    return Duration(milliseconds: math.min(index * 40, capMs));
  }
}

/// Fade + rise entrance for cards, rows and sections.
///
/// A [TweenAnimationBuilder] is used instead of a controller so this works
/// inside lazy lists without disposing anything, and so hot-reload never
/// leaves a controller half-driven.
///
/// Set [scale] to false for full-width rows where a scale would read as a
/// wobble.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
    this.scale = true,
    this.duration = AppMotion.medium,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final bool scale;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: AppMotion.easeOut,
      builder: (BuildContext context, double t, Widget? child) {
        // Hold at zero during the stagger delay, then run the curve.
        final double totalMs = (duration + delay).inMilliseconds.toDouble();
        final double delayMs = delay.inMilliseconds.toDouble();
        final double raw = totalMs <= 0 ? 1 : ((t * totalMs - delayMs) / duration.inMilliseconds).clamp(0.0, 1.0);
        final double eased = AppMotion.easeOut.transform(raw);
        final double opacity = eased;
        final double dy = (1 - eased) * offset;
        final double s = scale ? 0.98 + 0.02 * eased : 1.0;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: s, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

/// Press feedback: shrinks to 0.97 while held, springs back on release.
///
/// Wrap tappable cards and hero metrics with this — the existing `InkWell`
/// gives a splash but no scale, so taps currently feel flat.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Animated number for XP / points / streak.
///
/// Numbers currently jump (e.g. after claiming). Counting up over 400ms makes
/// the reward feel earned. [format] defaults to plain int; pass
/// `NumberFormat.compact().format` for large XP.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.duration = AppMotion.slow,
    this.style,
    this.format,
  });

  final double value;
  final Duration duration;
  final TextStyle? style;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text((format ?? (double v) => '${v.round()}')(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.easeOut,
      builder: (BuildContext context, double v, _) => Text(
        (format ?? (double x) => '${x.round()}')(v),
        style: style,
      ),
    );
  }
}

/// Level ring that sweeps from 0 to [progress] on first build.
///
/// The static `CircularProgressIndicator(value:)` reads as a gauge that was
/// always there; sweeping it in ties the ring to the greeting moment.
class AnimatedLevelRing extends StatelessWidget {
  const AnimatedLevelRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 72,
    this.strokeWidth = 6,
  });

  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (MediaQuery.disableAnimationsOf(context)) {
      return _RingShell(
        size: size,
        strokeWidth: strokeWidth,
        progress: progress.clamp(0.0, 1.0),
        backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
        child: child,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: AppMotion.slow + const Duration(milliseconds: 200),
      curve: AppMotion.easeOut,
      builder: (BuildContext context, double v, _) => _RingShell(
        size: size,
        strokeWidth: strokeWidth,
        progress: v,
        backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
        child: child,
      ),
    );
  }
}

class _RingShell extends StatelessWidget {
  const _RingShell({
    required this.size,
    required this.strokeWidth,
    required this.progress,
    required this.backgroundColor,
    required this.child,
  });

  final double size;
  final double strokeWidth;
  final double progress;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: backgroundColor,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Gentle entrance float for the mascot / empty-state illustrations.
///
/// A single 500ms rise-and-settle (not an infinite loop) so `pumpAndSettle`
/// in widget tests still completes. The looped breathing version blocked every
/// route that shows a mascot (dashboard preview card, profile, sheets) because
/// a `repeat()` ticker never settles. The single rise still feels alive on
/// appearance, respects reduced motion, and composes with [PopIn] for
/// celebrations.
class Floater extends StatelessWidget {
  const Floater({super.key, required this.child, this.amplitude = 6});

  final Widget child;
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.medium + const Duration(milliseconds: 100),
      curve: AppMotion.easeOut,
      builder: (BuildContext context, double t, Widget? child) => Transform.translate(
        offset: Offset(0, (1 - t) * amplitude),
        child: Opacity(opacity: 0.4 + 0.6 * t, child: child),
      ),
      child: child,
    );
  }
}

/// Celebration pop for claimable rewards: slow scale-in with a spring.
///
/// Wrap the amber gift icon so a newly-claimable card draws the eye without
/// a full-screen confetti overlay.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow + delay,
      curve: AppMotion.spring,
      builder: (BuildContext context, double t, Widget? child) {
        final double totalMs = (AppMotion.slow + delay).inMilliseconds.toDouble();
        final double raw = totalMs <= 0
            ? 1
            : ((t * totalMs - delay.inMilliseconds) / AppMotion.slow.inMilliseconds).clamp(0.0, 1.0);
        final double eased = AppMotion.spring.transform(raw.clamp(0.0, 1.0));
        return Transform.scale(scale: eased.clamp(0.0, 1.2), child: Opacity(opacity: raw.clamp(0.0, 1.0), child: child));
      },
      child: child,
    );
  }
}

/// Three-dot typing indicator for the Echo "thinking" bubble.
///
/// Replaces a lone spinner: dots read as someone typing, and the stagger
/// makes a 2-second wait feel attended rather than stuck.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color, this.size = 6});

  final Color? color;
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color dot = widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (int i = 0; i < 3; i++) _Dot(color: dot, size: widget.size, dy: 0)],
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++)
            _Dot(
              color: dot,
              size: widget.size,
              dy: -3.2 * math.sin((_controller.value * 3 - i * 0.45) * math.pi).clamp(-1.0, 1.0).abs() + 1.6,
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size, required this.dy});

  final Color color;
  final double size;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size * 0.28),
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Shake for invalid auth forms — a 300ms horizontal nudge that says "no"
/// without a dialog.
class Shaker extends StatefulWidget {
  const Shaker({super.key, required this.child, required this.shakeKey});

  final Widget child;

  /// Bump this value to trigger a shake.
  final int shakeKey;

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _last = widget.shakeKey;
  }

  @override
  void didUpdateWidget(Shaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeKey != _last) {
      _last = widget.shakeKey;
      if (!MediaQuery.disableAnimationsOf(context)) _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double dx = math.sin(t * math.pi * 4) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Page transition shared by full-screen routes pushed on the root navigator
/// (exam detail / taking / chat thread): fade + slight rise, iOS-style.
///
/// Tab switches keep go_router's default (no animation) so the bar feels
/// instant; only *places you go into and come back from* animate.
class AppPageTransition extends StatelessWidget {
  const AppPageTransition({super.key, required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curved = CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
