import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/common.dart';
import '../../domain/assignment_extras.dart';

/// Design-first file viewer. No download backend yet.
///
/// Flow for testing: detail file row tap -> this sheet -> mock pages ->
/// Download (simulated snackbar). Backend later: `file_url` + cached viewer.
Future<void> showAttachmentViewerSheet(
  BuildContext context,
  TeacherAttachment file, {
  String? subtitle,
}) {
  return AppSheet.show<void>(
    context: context,
    title: file.name,
    subtitle: subtitle ?? '${file.kind.label} · ${file.sizeLabel}',
    icon: file.kind.icon,
    children: <Widget>[_ViewerBody(file: file)],
  );
}

class _ViewerBody extends StatelessWidget {
  const _ViewerBody({required this.file});
  final TeacherAttachment file;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Mock preview: 3 page placeholders (or image block).
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(file.kind.icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.kind == AttachmentKind.image
                          ? 'Diagram preview (mock)'
                          : '3 pages · mock preview',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  StatusChip(label: file.kind.label, color: scheme.primary, dense: true),
                ],
              ),
              const SizedBox(height: 10),
              if (file.kind == AttachmentKind.image)
                Container(
                  height: 150,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.photo_fill_on_rectangle_fill, size: 44, color: scheme.primary.withValues(alpha: 0.6)),
                )
              else
                for (int i = 1; i <= 3; i++)
                  Container(
                    margin: EdgeInsets.only(bottom: i == 3 ? 0 : 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Page $i', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 5),
                        Container(height: 8, width: MediaQuery.sizeOf(context).width * 0.55, decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 5),
                        Container(height: 8, width: MediaQuery.sizeOf(context).width * 0.35, decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showSnack(context, 'Saved to downloads (design preview).'),
                icon: const Icon(CupertinoIcons.cloud_download_fill, size: 16),
                label: const Text('Download'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showSnack(context, 'Share link copied (design preview).'),
                icon: const Icon(CupertinoIcons.share, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const SheetNote(message: 'Design preview: pages are placeholders. Backend will serve file_url with caching + real rendering later.'),
      ],
    );
  }
}
