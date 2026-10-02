import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/lsi_mascot.dart';
import '../../domain/assignment_models.dart';
import '../../state/assignment_providers.dart';

/// Design-first submit flow. No file_picker / backend yet.
///
/// Flow for testing:
/// list tap -> detail -> [Submit assignment] -> this sheet ->
/// pick mock file -> Confirm -> success state (mascot celebrating) ->
/// snackbar + list refresh. Backend later swaps `_confirm` with
/// `POST /assignments/:id/submit` multipart.
Future<void> showSubmitAssignmentSheet(BuildContext context, WidgetRef ref, AssignmentItem assignment) {
  return AppSheet.show<void>(
    context: context,
    title: assignment.submitted ? 'Resubmit assignment?' : 'Submit assignment?',
    subtitle: assignment.title,
    icon: CupertinoIcons.doc_plaintext,
    children: <Widget>[_SubmitBody(assignment: assignment)],
  );
}

class _MockFile {
  const _MockFile({required this.name, required this.sizeLabel, required this.icon});
  final String name;
  final String sizeLabel;
  final IconData icon;
}

const List<_MockFile> _mockFiles = <_MockFile>[
  _MockFile(name: 'reading-response.pdf', sizeLabel: '1.2 MB · PDF', icon: CupertinoIcons.doc_fill),
  _MockFile(name: 'limits-draft.docx', sizeLabel: '84 KB · DOCX', icon: CupertinoIcons.doc_text_fill),
  _MockFile(name: 'work-photo.jpg', sizeLabel: '2.4 MB · JPG', icon: CupertinoIcons.photo_fill),
];

class _SubmitBody extends ConsumerStatefulWidget {
  const _SubmitBody({required this.assignment});
  final AssignmentItem assignment;

  @override
  ConsumerState<_SubmitBody> createState() => _SubmitBodyState();
}

class _SubmitBodyState extends ConsumerState<_SubmitBody> {
  int? _picked = 0; // Pre-pick one so the design is testable in one tap.
  bool _busy = false;
  bool _done = false;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_picked == null) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
    ref.invalidate(assignmentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AssignmentItem a = widget.assignment;

    if (_done) {
      final _MockFile f = _mockFiles[_picked ?? 0];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Center(child: LsiMascot(mood: LsiMascotMood.celebrating, size: 88)),
          const SizedBox(height: 12),
          Center(child: Text('Handed in!', style: theme.textTheme.titleLarge)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '${f.name} sent for “${a.title}”.\nYour teacher will grade it — XP lands when graded.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.accents.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: <Widget>[
                Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: context.accents.success),
                const SizedBox(width: 10),
                Expanded(child: Text('Late? It still counts — on-time work earns full XP.', style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).maybePop();
              showSnack(context, '“${a.title}” submitted (design preview).');
            },
            child: const Text('Done'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Deadline + points strip.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: <Widget>[
              Icon(a.isOverdue ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.calendar, size: 18, color: a.isOverdue ? scheme.error : scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(a.dueAtLabel, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: a.isOverdue ? scheme.error : scheme.onSurface)),
                    Text('${a.pointsPossible} pts · ${a.courseName ?? 'General'}${a.isGroupWork ? ' · Group ${a.groupMin}–${a.groupMax}' : ''}', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('1 · Choose a file', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        // Mock picker — real file_picker wired later.
        for (int i = 0; i < _mockFiles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FileOption(
              file: _mockFiles[i],
              selected: _picked == i,
              onTap: _busy ? null : () => setState(() => _picked = i),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => showSnack(context, 'System picker comes with backend (file_picker pkg). Pick a mock file for now.'),
          icon: const Icon(CupertinoIcons.folder_fill, size: 16),
          label: const Text('Browse device…'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        const SizedBox(height: 14),
        Text('2 · Note to teacher (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLines: 2,
          enabled: !_busy,
          decoration: const InputDecoration(hintText: 'e.g. Part 3 was tricky — I showed my working on p.2'),
        ),
        const SizedBox(height: 12),
        const SheetNote(message: 'PDF, DOCX or photo · max 10 MB. Resubmits replace the previous file until grading starts.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _busy || _picked == null ? null : _confirm,
          icon: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(CupertinoIcons.paperplane_fill, size: 17),
          label: Text(_busy ? 'Uploading…' : a.submitted ? 'Resubmit ${_mockFiles[_picked ?? 0].name}' : 'Submit ${_mockFiles[_picked ?? 0].name}'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        if (a.submitted)
          const SheetNote(message: 'Design: resubmit keeps your place in the grading queue. Backend will return 409 once graded.'),
      ],
    );
  }
}

class _FileOption extends StatelessWidget {
  const _FileOption({required this.file, required this.selected, required this.onTap});
  final _MockFile file;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.10) : scheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.5), width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: <Widget>[
            Icon(file.icon, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(file.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(file.sizeLabel, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
