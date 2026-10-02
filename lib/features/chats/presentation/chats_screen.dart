import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../../shared/widgets/common.dart';
import '../domain/chat_models.dart';
import '../state/chat_providers.dart';

/// The conversation list for Echo, the study assistant.
///
/// New chats start here now (design-first fake create); rename + delete are
/// swipe/long-press actions backed by the fake until the real API lands.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _query = '';

  Future<void> _confirmDelete(int id, String title) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('“$title” will be removed from Recent on this device preview.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(chatSessionActionsProvider.notifier).remove(id);
      if (mounted) showSnack(context, 'Conversation deleted (design preview).');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not delete. Try again.', isError: true);
    }
  }

  Future<void> _rename(int id, String current) async {
    final TextEditingController c = TextEditingController(text: current == 'New chat' ? '' : current);
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'e.g. Integrals review')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(d).pop(c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (next == null || next.isEmpty || next == current) return;
    try {
      await ref.read(chatSessionActionsProvider.notifier).rename(id, next);
      if (mounted) showSnack(context, 'Renamed (design preview).');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not rename. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ChatSessions> sessions = ref.watch(chatSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: <Widget>[
          IconButton(
            tooltip: 'New chat',
            onPressed: () => context.push('/more/chats/new'),
            icon: const Icon(CupertinoIcons.plus),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(chatSessionsProvider),
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
          const ProfileMenu(),
        ],
      ),
      body: sessions.when(
        loading: () => const SkeletonList(count: 4),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(chatSessionsProvider),
        ),
        data: (ChatSessions data) {
          final String q = _query.trim().toLowerCase();
          final List<ChatSessionSummary> shown = q.isEmpty
              ? data.sessions
              : data.sessions
                  .where((ChatSessionSummary s) =>
                      s.title.toLowerCase().contains(q) ||
                      (s.lastMessage ?? '').toLowerCase().contains(q))
                  .toList(growable: false);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(chatSessionsProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _EchoCard(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton.icon(
                    onPressed: () => context.push('/more/chats/new'),
                    icon: const Icon(CupertinoIcons.plus, size: 18),
                    label: const Text('New chat'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    onChanged: (String v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search conversations',
                      prefixIcon: Icon(CupertinoIcons.search, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
                if (data.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: EmptyView(
                      title: 'No conversations yet',
                      message:
                          'Start a new chat below — it saves here with full history.',
                      icon: CupertinoIcons.chat_bubble_text,
                    ),
                  )
                else if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: EmptyView(
                      title: 'No matches',
                      message: 'Try a different search, or start a new chat.',
                      icon: CupertinoIcons.search,
                    ),
                  )
                else ...<Widget>[
                  const SectionHeader(
                    title: 'Recent',
                    subtitle: 'Newest first · swipe to delete · long-press to rename',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GroupedList(
                      children: <Widget>[
                        for (int i = 0; i < shown.length; i++)
                          Dismissible(
                            key: ValueKey<int>(shown[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 20),
                            ),
                            confirmDismiss: (_) async {
                              await _confirmDelete(shown[i].id, shown[i].title);
                              return false; // provider refresh rebuilds instead
                            },
                            child: GestureDetector(
                              onLongPress: () => _rename(shown[i].id, shown[i].title),
                              child: _SessionRow(
                                session: shown[i],
                                isFirst: i == 0,
                                isLast: i == shown.length - 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// What Echo is and how a conversation gets here. Without it the list of titles
/// reads like an inbox with no sender.
class _EchoCard extends StatelessWidget {
  const _EchoCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(CupertinoIcons.sparkles, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Echo', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    'Your study assistant. Start a new chat below — it saves here with full history.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.isFirst, required this.isLast});

  final ChatSessionSummary session;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GroupedRow(
      isFirst: isFirst,
      isLast: isLast,
      onTap: () => context.push('/more/chats/${session.id}'),
      showChevron: true,
      leading: Container(
        height: 36,
        width: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: session.isUntitled
              ? scheme.onSurface.withValues(alpha: 0.06)
              : scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          session.isUntitled ? CupertinoIcons.chat_bubble : CupertinoIcons.chat_bubble_fill,
          size: 17,
          color: session.isUntitled ? scheme.onSurfaceVariant : scheme.primary,
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            session.timeLabel,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          // Plain text, not a chip: a badge here would read as unread messages,
          // and the endpoint reports a total count.
          if (session.messageCount > 0)
            Text(
              '${session.messageCount} messages',
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: session.isUntitled ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            session.lastMessage ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
