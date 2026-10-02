import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common.dart';
import '../../assignments/domain/assignment_models.dart';
import '../../assignments/state/assignment_providers.dart';
import '../../exams/domain/exam_models.dart';
import '../../exams/state/exam_providers.dart';
import '../../profile/domain/xp_history.dart';
import '../../profile/state/profile_providers.dart';

/// A short digest rather than a fourth list of the same rows: what is about to
/// need the student, and what they earned recently.
///
/// The exam endpoint feeds both the Exams tab and this hub, so the exams below
/// are exactly the ones on that tab — this page only narrows them to what is
/// open or imminent and mixes in assignment deadlines.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ExamListState> exams = ref.watch(examListProvider);
    final AsyncValue<AssignmentsData> assignments = ref.watch(assignmentsProvider);
    final AsyncValue<XpHistory> history = ref.watch(xpHistoryProvider);

    final bool nothingYet =
        exams.value == null && assignments.value == null && history.value == null;
    if (nothingYet && (exams.isLoading || assignments.isLoading || history.isLoading)) {
      return Scaffold(
        appBar: _appBar(ref),
        body: const SkeletonList(count: 5),
      );
    }

    if (nothingYet && exams.hasError && assignments.hasError && history.hasError) {
      return Scaffold(
        appBar: _appBar(ref),
        body: ErrorView(
          message: '${exams.error}',
          onRetry: () {
            ref.invalidate(examListProvider);
            ref.invalidate(assignmentsProvider);
            ref.invalidate(xpHistoryProvider);
          },
        ),
      );
    }

    final List<_Agenda> agenda = _agenda(
      exams: <ExamCard>[
        for (final ExamSeasonGroup group in exams.value?.groups ?? const <ExamSeasonGroup>[])
          ...group.exams,
      ],
      assignments: assignments.value?.outstanding ?? const <AssignmentItem>[],
    );
    final List<XpEntry> ledger = history.value?.entries ?? const <XpEntry>[];

    return Scaffold(
      appBar: _appBar(ref),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(examListProvider);
          ref.invalidate(assignmentsProvider);
          ref.invalidate(xpHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            if (agenda.isEmpty && ledger.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyView(
                  title: 'Nothing on the horizon',
                  message: 'Open exams, upcoming deadlines and your XP ledger all show up here.',
                  icon: CupertinoIcons.time,
                ),
              ),
            if (agenda.isNotEmpty) ...<Widget>[
              SectionHeader(
                title: 'Needs you',
                subtitle: '${agenda.length} ${agenda.length == 1 ? 'thing' : 'things'} open or due soon',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GroupedList(
                  children: <Widget>[
                    for (int i = 0; i < agenda.length; i++)
                      _AgendaRow(
                        item: agenda[i],
                        isFirst: i == 0,
                        isLast: i == agenda.length - 1,
                      ),
                  ],
                ),
              ),
            ],
            if (ledger.isNotEmpty) ...<Widget>[
              const SectionHeader(title: 'Recent XP'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GroupedList(
                  children: <Widget>[
                    for (int i = 0; i < ledger.length && i < 6; i++)
                      _XpRow(
                        entry: ledger[i],
                        isFirst: i == 0,
                        isLast: i == (ledger.length > 6 ? 6 : ledger.length) - 1,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static AppBar _appBar(WidgetRef ref) {
    return AppBar(
      title: const Text('Activity'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(examListProvider);
            ref.invalidate(assignmentsProvider);
            ref.invalidate(xpHistoryProvider);
          },
          icon: const Icon(CupertinoIcons.arrow_clockwise),
        ),
        const ProfileMenu(),
      ],
    );
  }
}

/// One row of the "needs you" list, whatever it came from.
class _Agenda {
  const _Agenda({
    required this.title,
    required this.subtitle,
    required this.when,
    required this.icon,
    required this.tone,
    required this.examId,
  });

  final String title;
  final String subtitle;
  final DateTime? when;
  final IconData icon;
  final Color tone;

  /// Null for assignment deadlines, which have nowhere of their own to open.
  final int? examId;

  String get whenLabel {
    final DateTime? target = when;
    if (target == null) return 'No deadline';

    final DateTime now = DateTime.now();
    final int days = DateTime(target.year, target.month, target.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    if (days < 0) return '${days.abs()}d ago';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'in ${days}d';
  }
}

List<_Agenda> _agenda({required List<ExamCard> exams, required List<AssignmentItem> assignments}) {
  final ColorScheme scheme = const ColorScheme.light();
  final List<_Agenda> items = <_Agenda>[
    for (final ExamCard exam in exams)
      if (exam.isOpenNow || exam.isUpcoming)
        _Agenda(
          title: exam.title,
          subtitle: <String>[
            'Exam',
            '${exam.durationMinutes} min',
            '${exam.submittedParts}/${exam.partsCount} parts',
          ].join(' · '),
          when: exam.startsAt,
          icon: exam.isOpenNow ? CupertinoIcons.doc_text_fill : CupertinoIcons.doc_text,
          tone: exam.isOpenNow ? AppTheme.success : scheme.primary,
          examId: exam.id,
        ),
    for (final AssignmentItem assignment in assignments)
      if (assignment.dueAt != null)
        _Agenda(
          title: assignment.title,
          subtitle: <String>['Assignment', '${assignment.pointsPossible} pts']
              .join(' · '),
          when: assignment.dueAt,
          icon: CupertinoIcons.doc_plaintext,
          tone: assignment.isOverdue ? scheme.error : AppTheme.xp,
          examId: null,
        ),
  ];

  items.sort(( _Agenda a,  _Agenda b) =>
      (a.when ?? DateTime(2999)).compareTo(b.when ?? DateTime(2999)));

  return items;
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.item, required this.isFirst, required this.isLast});

  final _Agenda item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      showChevron: item.examId != null,
      onTap: item.examId == null ? () => context.push('/more/assignments') : () => context.push('/exams/${item.examId}'),
      leading: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: item.tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(item.icon, size: 17, color: item.tone),
      ),
      trailing: Text(
        item.whenLabel,
        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            <String>[
              item.subtitle,
              if (item.when != null) DateFormat.MMMd().add_jm().format(item.when!),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _XpRow extends StatelessWidget {
  const _XpRow({required this.entry, required this.isFirst, required this.isLast});

  final XpEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppColors accents = context.accents;
    final Color tone = entry.isCredit ? accents.xp : scheme.error;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(
        entry.isCredit ? CupertinoIcons.arrow_up_circle_fill : CupertinoIcons.arrow_down_circle_fill,
        size: 22,
        color: tone,
      ),
      trailing: Text(
        entry.amountLabel,
        style: theme.textTheme.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            entry.description ?? entry.createdAtLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
