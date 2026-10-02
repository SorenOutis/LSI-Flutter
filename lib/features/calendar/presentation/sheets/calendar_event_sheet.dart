import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_sheet.dart';
import '../../../../shared/widgets/common.dart';
import '../../domain/calendar_data.dart';

/// Design-first event detail for non-exam rows.
///
/// CalendarEvent carries no assignment id (title/subtitle/time only), so this
/// explains the event and deep-links to the right list. Backend later can add
/// `assignmentId` and the button can push the detail directly.
Future<void> showCalendarEventSheet(BuildContext context, CalendarEvent event) {
  final bool isAssignment = event.kind == CalendarEventKind.assignmentDue ||
      event.kind == CalendarEventKind.assignmentOverdue;
  return AppSheet.show<void>(
    context: context,
    title: event.title,
    subtitle: event.kind.label,
    icon: isAssignment ? CupertinoIcons.pencil_outline : CupertinoIcons.flame,
    children: <Widget>[
      Row(
        children: <Widget>[
          if (event.time != null) ...<Widget>[
            StatusChip(label: event.time!, color: Theme.of(context).colorScheme.primary, dense: true),
            const SizedBox(width: 6),
          ],
          if (event.subtitle != null)
            Flexible(
              child: Text(
                event.subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      SheetNote(
        message: switch (event.kind) {
          CalendarEventKind.assignmentOverdue =>
            'Past its deadline and not handed in. It still counts — open Assignments to submit it now.',
          CalendarEventKind.assignmentDue =>
            'Still open. Open Assignments to review the brief, files and rubric, then submit.',
          CalendarEventKind.login =>
            'You earned XP this day, which is what keeps the streak alive. Opening the app alone does not count.',
          _ => 'Exam windows open from the Exams tab.',
        },
      ),
      const SizedBox(height: 12),
      if (isAssignment)
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/more/assignments');
          },
          icon: const Icon(CupertinoIcons.doc_plaintext, size: 17),
          label: const Text('Open assignments'),
        )
      else
        FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
    ],
  );
}
