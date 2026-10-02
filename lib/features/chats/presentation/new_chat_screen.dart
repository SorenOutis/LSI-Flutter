import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/lsi_mascot.dart';
import '../state/chat_providers.dart';

/// Design-first new chat: mascot + suggestions + composer.
///
/// First send creates the session (`POST /chats`) then pushes the thread,
/// ChatGPT-style. Works fully on fake backend; real API later.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

const List<String> kChatSuggestions = <String>[
  'Explain derivatives in 2 minutes',
  'Quiz me on integrals',
  'Help plan my Rizal essay',
  'What will be on the midterm?',
];

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _draft = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _start([String? preset]) async {
    final String text = (preset ?? _draft.text).trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final int id = await ref
          .read(newChatControllerProvider.notifier)
          .create(firstMessage: text);
      if (!mounted) return;
      // Replace so Back returns to the list, not this starter.
      context.pushReplacement('/more/chats/$id');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, 'Could not start the chat. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MascotMessage(
                mood: LsiMascotMood.studying,
                title: 'Ask Echo anything',
                subtitle:
                    'Study help grounded in your sections and open assignments. First message creates the conversation.',
              ),
            ),
          ),
          const SectionHeader(title: 'Try one', subtitle: 'Tap to start with it'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String s in kChatSuggestions)
                ActionChip(
                  label: Text(s, style: theme.textTheme.bodySmall),
                  avatar: Icon(CupertinoIcons.sparkles, size: 14, color: scheme.primary),
                  onPressed: _busy ? null : () => _start(s),
                ),
            ],
          ),
          const SectionHeader(title: 'Or write your own'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _start(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Why is the derivative of x² 2x?',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _draft,
                    builder: (BuildContext context, TextEditingValue value, Widget? _) {
                      if (_busy) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: CupertinoSpinner(size: 18),
                        );
                      }
                      return IconButton.filled(
                        tooltip: 'Start chat',
                        onPressed: value.text.trim().isEmpty ? null : () => _start(),
                        icon: const Icon(CupertinoIcons.arrow_up, size: 18),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Conversations save to Recent automatically.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
