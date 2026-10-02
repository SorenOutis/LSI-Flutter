import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'app_motion.dart';

/// The app's modal sheet: a grab handle, a title row, and a scrolling body.
///
/// One scaffold for every sheet so the level, streak and points modals cannot
/// drift apart in height, dismissal or padding. iOS sheets are inset from the
/// screen edges and cap their height, which Material's default
/// `showModalBottomSheet` does not, so the shape is built here rather than at
/// each call site.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.icon,
  });

  final String title;
  final String? subtitle;

  /// The sheet's content, laid out in a column.
  final List<Widget> children;

  /// Optional leading glyph, tinted to the sheet's accent.
  final IconData? icon;

  /// Presents [builder] as a sheet.
  ///
  /// Wraps the call so no screen has to remember the shape: a bounded height, a
  /// safe-area inset, and a Material route so the sheet's own text styles apply.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      // The sheet supplies its own background and radius; Material's default
      // one clips the handle on a rounded device.
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (BuildContext context) => AppSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        // From the screen edge on a landscape phone, and from the keyboard on
        // one that shows it.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(icon, size: 20, color: scheme.primary),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 24,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  // Leaves the sheet clear of the home indicator.
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    // Staggered rise so a sheet's explanation reads top-down
                    // instead of flashing in as one block.
                    for (int i = 0; i < children.length; i++)
                      FadeSlideIn(
                        delay: AppMotion.stagger(i, capMs: 160),
                        offset: 10,
                        scale: false,
                        child: Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 0),
                          child: children[i],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short explanatory paragraph inside a sheet.
///
/// Sheets that describe how something is earned need to say where the number
/// comes from; a line of grey body text reads as a footnote and is skipped,
/// while the same text in a labelled block is read.
class SheetNote extends StatelessWidget {
  const SheetNote({super.key, required this.message, this.icon = Icons.info_outline_rounded});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: muted.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}