import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/common.dart';
import '../domain/chat_models.dart';
import '../state/chat_providers.dart';
import 'new_chat_screen.dart' show kChatSuggestions;

/// One conversation with Echo: the full history and a composer.
///
/// Opened full-screen on the root navigator rather than inside the tab shell —
/// the same treatment the exam flow gets. A thread is a place you go and come
/// back from, and a composer sitting above a persistent tab bar reads as a
/// half-open screen.
///
/// The title is read from the session list, which is already in memory when a
/// row is tapped. A deep link into a conversation that is not on the first page
/// falls back to a neutral title rather than blocking the thread.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _draft = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _draft.text.trim();
    if (text.isEmpty || _sending) return;

    final ChatThreadController thread = ref.read(chatThreadProvider(widget.sessionId).notifier);

    // Shown immediately, before the round trip: making the student wait to see
    // their own message makes a slow connection feel like a broken app.
    final ChatMessage outgoing = ChatMessage.outgoing(text);
    thread.append(outgoing);
    _draft.clear();
    setState(() => _sending = true);
    _scrollToEnd();

    final String? reply = await ref.read(chatComposerProvider(widget.sessionId).notifier).send(text);

    if (!mounted) return;
    setState(() => _sending = false);

    if (reply == null) {
      // Retract the optimistic turn and put the text back in the composer: a
      // failed send must not leave the message looking delivered, and must not
      // lose what the student typed.
      thread.retract(outgoing);
      _draft.text = text;
      showSnack(context, 'Echo could not answer. Check your connection and try again.', isError: true);
      _scrollToEnd();
      return;
    }

    thread.append(ChatMessage.reply(reply));
    // The list previews the last message and counts the turns, so it is stale
    // the moment a reply lands.
    ref.invalidate(chatSessionsProvider);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    // After the frame that appended the turn, once the list has an extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  /// Design-first regenerate: resends the last user turn as a new request.
  Future<void> _regenerate() async {
    if (_sending) return;
    final ChatThread? current = ref.read(chatThreadProvider(widget.sessionId)).value;
    if (current == null || current.messages.isEmpty) return;
    String? lastUser;
    for (int i = current.messages.length - 1; i >= 0; i--) {
      if (current.messages[i].isUser) {
        lastUser = current.messages[i].content;
        break;
      }
    }
    if (lastUser == null || lastUser.trim().isEmpty) {
      showSnack(context, 'Nothing to regenerate yet.');
      return;
    }
    setState(() => _sending = true);
    final String? reply =
        await ref.read(chatComposerProvider(widget.sessionId).notifier).send(lastUser);
    if (!mounted) return;
    setState(() => _sending = false);
    if (reply == null) {
      showSnack(context, 'Echo could not answer. Try again.', isError: true);
      return;
    }
    ref.read(chatThreadProvider(widget.sessionId).notifier).append(ChatMessage.reply(reply));
    ref.invalidate(chatSessionsProvider);
    _scrollToEnd();
  }

  Future<void> _loadOlder() async {
    final bool more =
        await ref.read(chatThreadProvider(widget.sessionId).notifier).loadMore();
    if (!mounted) return;
    if (!more) showSnack(context, 'You are at the start of this conversation.');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ChatThread> thread = ref.watch(chatThreadProvider(widget.sessionId));
    final ChatSessionSummary? summary = ref.watch(chatSessionsProvider).value?.byId(widget.sessionId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          summary?.title ?? 'Conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Regenerate last answer',
            onPressed: thread.hasValue ? _regenerate : null,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: thread.when(
        loading: () => const LoadingView(message: 'Loading conversation…'),
        error: (Object error, StackTrace _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(chatThreadProvider(widget.sessionId)),
        ),
        data: (ChatThread data) => _Conversation(
          thread: data,
          sending: _sending,
          controller: _scroll,
          onLoadOlder: data.hasMore ? _loadOlder : null,
          onPickSuggestion: (String s) {
            _draft.text = s;
            _send();
          },
        ),
      ),
      // No composer when the history could not be loaded: sending into a thread
      // the student cannot read is worse than not sending.
      bottomNavigationBar: thread.hasValue
          ? SafeArea(
              top: false,
              child: _Composer(controller: _draft, sending: _sending, onSend: _send),
            )
          : null,
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.thread,
    required this.sending,
    required this.controller,
    this.onLoadOlder,
    this.onPickSuggestion,
  });

  final ChatThread thread;
  final bool sending;
  final ScrollController controller;
  final VoidCallback? onLoadOlder;
  final ValueChanged<String>? onPickSuggestion;

  @override
  Widget build(BuildContext context) {
    if (thread.isEmpty && !sending) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        children: <Widget>[
          const EmptyView(
            title: 'Start the conversation',
            message: 'Send the first message below — or tap a suggestion.',
            icon: CupertinoIcons.chat_bubble_text,
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String s in kChatSuggestions.take(3))
                ActionChip(
                  label: Text(s, style: Theme.of(context).textTheme.bodySmall),
                  onPressed: onPickSuggestion == null ? null : () => onPickSuggestion!(s),
                ),
            ],
          ),
        ],
      );
    }

    final List<Widget> rows = <Widget>[];
    DateTime? previousDay;

    if (thread.hasMore && onLoadOlder != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: TextButton.icon(
              onPressed: onLoadOlder,
              icon: const Icon(CupertinoIcons.chevron_up, size: 14),
              label: const Text('Load older messages'),
            ),
          ),
        ),
      );
    }

    for (final ChatMessage message in thread.messages) {
      final DateTime? day = message.createdAt;
      // A date rule whenever the conversation crosses into another day, the way
      // a message thread is read rather than a log.
      if (day != null && !_isSameDay(previousDay, day)) {
        rows.add(_DayRule(day: day));
        previousDay = day;
      }
      rows.add(_Bubble(message: message));
    }

    if (sending) rows.add(const _ThinkingBubble());

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: rows,
    );
  }

  static bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayRule extends StatelessWidget {
  const _DayRule({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int gap = DateTime(day.year, day.month, day.day).difference(today).inDays;

    final String label = switch (gap) {
      0 => 'Today',
      -1 => 'Yesterday',
      _ => DateFormat.yMMMEd().format(day),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool mine = message.isUser;

    return FadeSlideIn(
      offset: 8,
      scale: false,
      duration: AppMotion.fast,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (!mine) ...<Widget>[
              Container(
                height: 26,
                width: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.sparkles, size: 13, color: scheme.primary),
              ),
              const SizedBox(width: 8),
            ],
            // Flexible, not a bare ConstrainedBox: the row is what actually
            // bounds a bubble, and MediaQuery is only the target width. Sizing off
            // MediaQuery alone overflows whenever the two disagree — inside a
            // nested navigator, mid-transition, or under a wide text scale.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
                child: GestureDetector(
                  // Long-press copies the turn — the cheapest save/share until
                  // the backend offers exports.
                  onLongPress: () async {
                    await Clipboard.setData(ClipboardData(text: message.content));
                    if (context.mounted) showSnack(context, 'Copied to clipboard.');
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.easeOut,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: mine ? scheme.primary : context.accents.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        // The corner nearest the sender is tucked in, so a run of
                        // messages from one side reads as a single column.
                        bottomLeft: Radius.circular(mine ? 18 : 5),
                        bottomRight: Radius.circular(mine ? 5 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          message.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mine ? scheme.onPrimary : scheme.onSurface,
                            height: 1.35,
                          ),
                        ),
                        if (message.hasThinking) _Reasoning(text: message.thinking!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The assistant's reasoning trace, collapsed by default.
///
/// It is worth keeping — it explains a graded answer — but it is not the answer,
/// so it never leads the bubble.
class _Reasoning extends StatefulWidget {
  const _Reasoning({required this.text});

  final String text;

  @override
  State<_Reasoning> createState() => _ReasoningState();
}

class _ReasoningState extends State<_Reasoning> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: AppMotion.fast,
                  curve: AppMotion.easeOut,
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 11,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _open ? 'Hide reasoning' : 'Reasoning',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppMotion.medium,
            curve: AppMotion.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: muted.withValues(alpha: 0.4), width: 2)),
                      ),
                      child: Text(
                        widget.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FadeSlideIn(
      offset: 8,
      scale: false,
      duration: AppMotion.fast,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: context.accents.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const TypingDots(),
                  const SizedBox(width: 10),
                  Text(
                    'Echo is thinking…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: context.accents.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Ask Echo a question',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // A send button that lights up exactly when there is something to
          // send, and a spinner in its place while a reply is in flight.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (BuildContext context, TextEditingValue value, Widget? _) {
              if (sending) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: CupertinoSpinner(size: 18),
                );
              }

              final bool canSend = value.text.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: IconButton.filled(
                  tooltip: 'Send',
                  onPressed: canSend ? onSend : null,
                  icon: const Icon(CupertinoIcons.arrow_up, size: 18),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
