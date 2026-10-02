import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common.dart';
import '../../dashboard/state/dashboard_providers.dart';
import '../domain/calendar_data.dart';
import '../state/calendar_providers.dart';
import 'sheets/calendar_event_sheet.dart';

/// Month grid plus an agenda list, built entirely from the dashboard payload.
///
/// There is no calendar endpoint on the backend, so this reuses
/// `dashboardProvider` rather than adding a second fetch of the same data. That
/// also means the calendar is never more out of date than the dashboard.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CalendarData> calendar = ref.watch(calendarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
          const ProfileMenu(),
        ],
      ),
      body: calendar.when(
        loading: () => const SkeletonList(count: 5),
        error: (Object error, StackTrace stack) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (CalendarData data) => _CalendarBody(data: data),
      ),
    );
  }
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.data});

  final CalendarData data;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  @override
  Widget build(BuildContext context) {
    final CalendarData data = ref.watch(calendarProvider).value ?? widget.data;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _MonthNavigator(data: data),
          _MonthGrid(data: data),
          const SizedBox(height: 8),
          _Agenda(data: data),
        ],
      ),
    );
  }
}

/// Month title with chevrons to page through months.
class _MonthNavigator extends ConsumerWidget {
  const _MonthNavigator({required this.data});

  final CalendarData data;

  void _shift(BuildContext context, WidgetRef ref, int months) {
    final DateTime next = DateTime(data.focusedMonth.year, data.focusedMonth.month + months);
    ref.read(calendarViewProvider.notifier).focusMonth(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_left),
            tooltip: 'Previous month',
            onPressed: () => _shift(context, ref, -1),
          ),
          Expanded(
            child: Text(
              data.focusedMonthLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_right),
            tooltip: 'Next month',
            onPressed: () => _shift(context, ref, 1),
          ),
          // A visible "today" affordance; the grid can be paged away from it.
          if (DateTime(data.focusedMonth.year, data.focusedMonth.month) !=
              DateTime(DateTime.now().year, DateTime.now().month))
            TextButton(
              onPressed: () => ref.read(calendarViewProvider.notifier).focusMonth(
                DateTime(DateTime.now().year, DateTime.now().month),
              ),
              child: const Text('Today'),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// A Monday-start month grid. Each day shows a dot count when it has entries
/// and a filled background when the student logged in that day.
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.data});

  final CalendarData data;

  static const List<String> _weekdayInitials = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = context.scheme;
    final DateTime today = CalendarData.dayOf(DateTime.now());
    final List<DateTime> grid = CalendarData.monthGrid(data.focusedMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final String initial in _weekdayInitials)
                Expanded(
                  child: Center(
                    child: Text(
                      initial,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              // Tall enough for the day number plus a dot row underneath.
              childAspectRatio: 0.92,
            ),
            itemCount: grid.length,
            itemBuilder: (BuildContext context, int index) {
              final DateTime day = grid[index];
              final bool inMonth = day.month == data.focusedMonth.month;
              final bool isToday = CalendarData.dateKeyOf(day) == CalendarData.dateKeyOf(today);
              final bool isSelected = CalendarData.dateKeyOf(day) ==
                  CalendarData.dateKeyOf(data.selectedDate);
              final List<CalendarEvent> dayEvents = data.eventsOn(day);
              final bool loggedIn = data.daysWithActivity.contains(CalendarData.dateKeyOf(day));

              return GestureDetector(
                onTap: () => ref.read(calendarViewProvider.notifier).selectDate(day),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Today is a ring, selection is a filled disc: two states
                    // that would collide if both used a fill.
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary : null,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected ? Border.all(color: scheme.primary, width: 1.5) : null,
                      ),
                      child: Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? scheme.onPrimary
                              : (inMonth ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.28)),
                          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // A login day is a faint dot; a scheduled day is a
                          // solid accent dot, so the two never look the same.
                          if (loggedIn)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: scheme.onSurface.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (dayEvents.isNotEmpty)
                            Container(
                              width: dayEvents.length > 1 ? 12 : 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: dayEvents.any((CalendarEvent e) => e.isOverdue)
                                    ? scheme.error
                                    : scheme.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Upcoming days, grouped, as an inset grouped list.
class _Agenda extends ConsumerWidget {
  const _Agenda({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = context.scheme;
    final DateTime today = CalendarData.dayOf(DateTime.now());

    // The selected day's own events first, then everything upcoming, so a tap
    // on a day always surfaces what is on it.
    final List<CalendarDayGroup> groups = data.agendaFrom(today);

    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
        child: EmptyView(
          title: 'Nothing scheduled',
          message: 'Exams and assignment deadlines will show up here as they are announced.',
          icon: CupertinoIcons.calendar,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final CalendarDayGroup group in groups) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(20, group == groups.first ? 20 : 18, 20, 8),
            child: Row(
              children: [
                Text(
                  group.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: group.isOverdue ? scheme.error : scheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    height: 1,
                    color: (group.isOverdue ? scheme.error : scheme.outlineVariant).withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GroupedList(
              children: [
                for (int i = 0; i < group.events.length; i++)
                  _AgendaRow(
                    event: group.events[i],
                    isFirst: i == 0,
                    isLast: i == group.events.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.event, required this.isFirst, required this.isLast});

  final CalendarEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.scheme;
    final TextTheme text = Theme.of(context).textTheme;

    final Color accent = switch (event.kind) {
      CalendarEventKind.examOpen => context.accents.success,
      CalendarEventKind.examUpcoming => scheme.primary,
      CalendarEventKind.examEnded => scheme.onSurfaceVariant,
      CalendarEventKind.assignmentDue => context.accents.xp,
      CalendarEventKind.assignmentOverdue => scheme.error,
      CalendarEventKind.login => scheme.onSurfaceVariant,
    };

    final IconData icon = switch (event.kind) {
      CalendarEventKind.examOpen => CupertinoIcons.doc_text_fill,
      CalendarEventKind.examUpcoming => CupertinoIcons.doc_text,
      CalendarEventKind.examEnded => CupertinoIcons.checkmark_seal_fill,
      CalendarEventKind.assignmentDue => CupertinoIcons.pencil_outline,
      CalendarEventKind.assignmentOverdue => CupertinoIcons.exclamationmark_triangle_fill,
      CalendarEventKind.login => CupertinoIcons.flame,
    };

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      showChevron: event.examId != null || event.kind != CalendarEventKind.login,
      onTap: event.examId != null
          ? () => context.push('/exams/${event.examId}')
          : event.kind == CalendarEventKind.login
              ? null
              : () => showCalendarEventSheet(context, event),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          Text(
            event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: event.isOverdue ? scheme.error : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                event.kind.label,
                style: text.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.w600),
              ),
              if (event.time != null) ...[
                Text(' · ', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                Text(event.time!, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              if (event.subtitle != null) ...[
                Text(' · ', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                Text(event.subtitle!, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}


