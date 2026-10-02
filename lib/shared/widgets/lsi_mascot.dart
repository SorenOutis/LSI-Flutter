import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Fox mascot (from luav6) with a drawn fallback.
///
/// Drop PNGs into `assets/images/` (already registered in pubspec):
/// `fox-happy.png`, `fox-celebrating.png`, `fox-worried.png`, `fox-sad.png`,
/// `fox-sleeping.png`, `fox-studying.png` — or a single `fox.png` used for
/// every mood. When a file is missing, the drawn buddy below renders instead,
/// so tests and fresh checkouts never crash on a missing asset.
/// Call sites stay the same: `LsiMascot(mood: LsiMascotMood.happy)`.
enum LsiMascotMood { happy, celebrating, worried, sad, sleeping, studying }

/// Asset path for a mood, e.g. `assets/images/fox-happy.png`.
String foxAssetFor(LsiMascotMood mood) => 'assets/images/fox-${mood.name}.png';

class LsiMascot extends StatelessWidget {
  const LsiMascot({super.key, required this.mood, this.size = 72, this.float = true});

  final LsiMascotMood mood;
  final double size;

  /// Gentle breathing float. Disable inside dense rows where motion would
  /// distract (e.g. a 28px avatar in a list).
  final bool float;

  @override
  Widget build(BuildContext context) {
    final Widget face = SizedBox(
      height: size,
      width: size,
      child: ClipOval(
        child: Image.asset(
          foxAssetFor(mood),
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object err, StackTrace? stack) {
            // Fallback 1: single generic fox file.
            return Image.asset(
              'assets/images/fox.png',
              height: size,
              width: size,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object err2, StackTrace? stack2) {
                // Fallback 2: drawn buddy (no assets needed).
                return _ProceduralBuddy(mood: mood, size: size);
              },
            );
          },
        ),
      ),
    );

    final Widget wrapped = mood == LsiMascotMood.celebrating
        // Celebration gets a springy pop-in on top of the float, so a claimed
        // reward or a finished exam feels earned.
        ? PopIn(child: float ? Floater(child: face) : face)
        : (float ? Floater(child: face) : face);

    return Semantics(
      label: 'LSI fox feeling ${mood.name}',
      child: wrapped,
    );
  }
}

class _ProceduralBuddy extends StatelessWidget {
  const _ProceduralBuddy({required this.mood, required this.size});

  final LsiMascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _MoodStyle style = _styleFor(mood, scheme);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: style.body,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: style.body.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            // Ears.
            Positioned(
              top: size * 0.06,
              left: size * 0.12,
              child: _Ear(color: style.accent, size: size * 0.18),
            ),
            Positioned(
              top: size * 0.06,
              right: size * 0.12,
              child: _Ear(color: style.accent, size: size * 0.18),
            ),
            // Face. Eye size + gap scale with [size] so a 40px mascot
            // never overflows its circle (fixed 18px eyes + 10px gap = 46px).
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: size * 0.08),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Eye(closed: mood == LsiMascotMood.sleeping, size: size * 0.24),
                    SizedBox(width: size * 0.12),
                    _Eye(closed: mood == LsiMascotMood.sleeping, size: size * 0.24),
                  ],
                ),
                SizedBox(height: size * 0.05),
                _Mouth(mood: mood, color: style.mouth),
                if (mood == LsiMascotMood.celebrating) ...<Widget>[
                  const SizedBox(height: 2),
                  const Text('✨', style: TextStyle(fontSize: 12)),
                ],
                if (mood == LsiMascotMood.worried || mood == LsiMascotMood.sad) ...<Widget>[
                  const SizedBox(height: 2),
                  Icon(
                    mood == LsiMascotMood.sad
                        ? CupertinoIcons.drop_fill
                        : CupertinoIcons.exclamationmark_circle_fill,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ],
            ),
            // Belly patch.
            Positioned(
              bottom: size * 0.08,
              child: Container(
                height: size * 0.22,
                width: size * 0.42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      );
    }

  _MoodStyle _styleFor(LsiMascotMood m, ColorScheme scheme) {
    // Warm owl palette — distinct from XP amber / streak red so the mascot
    // never reads as a status dot.
    const Color bodyBlue = Color(0xFF5B8DEF);
    const Color bodyAmber = Color(0xFFF5A623);
    const Color bodyRed = Color(0xFFE57373);
    const Color bodySlate = Color(0xFF90A4AE);
    const Color bodyPurple = Color(0xFF9575CD);
    return switch (m) {
      LsiMascotMood.happy => _MoodStyle(body: bodyBlue, accent: const Color(0xFF3A6BD8), mouth: Colors.white),
      LsiMascotMood.celebrating =>
        _MoodStyle(body: bodyAmber, accent: const Color(0xFFD18A12), mouth: Colors.white),
      LsiMascotMood.studying =>
        _MoodStyle(body: bodyPurple, accent: const Color(0xFF6F54B8), mouth: Colors.white),
      LsiMascotMood.worried =>
        _MoodStyle(body: bodyAmber, accent: const Color(0xFFD18A12), mouth: Colors.white),
      LsiMascotMood.sad => _MoodStyle(body: bodyRed, accent: const Color(0xFFC45555), mouth: Colors.white),
      LsiMascotMood.sleeping =>
        _MoodStyle(body: bodySlate, accent: const Color(0xFF6B7F8A), mouth: Colors.white),
    };
  }
}

class _MoodStyle {
  const _MoodStyle({required this.body, required this.accent, required this.mouth});
  final Color body;
  final Color accent;
  final Color mouth;
}

class _Ear extends StatelessWidget {
  const _Ear({required this.color, this.size = 14});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.closed, this.size = 18});
  final bool closed;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (closed) {
      return Container(height: size * 0.16, width: size * 0.66, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)));
    }
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(height: size, width: size, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        Container(height: size * 0.5, width: size * 0.5, decoration: const BoxDecoration(color: Color(0xFF1C1C1E), shape: BoxShape.circle)),
        Positioned(top: size * 0.16, right: size * 0.16, child: Container(height: size * 0.22, width: size * 0.22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
      ],
    );
  }
}

class _Mouth extends StatelessWidget {
  const _Mouth({required this.mood, required this.color});
  final LsiMascotMood mood;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = switch (mood) {
      LsiMascotMood.sad => const BorderRadius.vertical(top: Radius.circular(10)),
      LsiMascotMood.sleeping => BorderRadius.circular(2),
      _ => const BorderRadius.vertical(bottom: Radius.circular(10)),
    };
    final double width = mood == LsiMascotMood.sleeping ? 10 : 18;
    final double height = mood == LsiMascotMood.sad ? 7 : (mood == LsiMascotMood.sleeping ? 2 : 9);
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.95), borderRadius: radius),
    );
  }
}

/// Small mascot + text row used in empty states and banners.
class MascotMessage extends StatelessWidget {
  const MascotMessage({super.key, required this.mood, required this.title, this.subtitle, this.size = 56});

  final LsiMascotMood mood;
  final String title;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        LsiMascot(mood: mood, size: size),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
