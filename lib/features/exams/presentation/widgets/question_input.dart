import 'package:flutter/material.dart';

import '../../domain/exam_models.dart';

/// Renders the right input for each of the six question types.
///
/// The widget is controlled: it reads the current answer from [answer] and
/// reports every edit through [onChanged]. Keeping the state in the parent is
/// what makes autosave and submit agree on what was answered.
class QuestionInput extends StatelessWidget {
  const QuestionInput({
    super.key,
    required this.question,
    required this.answer,
    required this.onChanged,
    this.revealed = false,
  });

  final ExamQuestion question;
  final Object? answer;

  /// `true` once the exam is closed and the key may be shown.
  final bool revealed;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return switch (question.type) {
      QuestionType.multipleChoice => _ChoiceList(
        options: question.options,
        selectedIndex: answer is int ? answer! as int : null,
        revealed: revealed,
        onSelect: (int index) => onChanged(index),
      ),
      QuestionType.trueFalse => _ChoiceList(
        options: const [
          QuestionOption(text: 'True', isCorrect: null, hasKey: false),
          QuestionOption(text: 'False', isCorrect: null, hasKey: false),
        ],
        selectedIndex: answer is int ? answer! as int : null,
        revealed: revealed,
        onSelect: (int index) => onChanged(index),
      ),
      QuestionType.identification => _TextAnswer(
        value: answer is String ? answer! as String : '',
        revealed: revealed,
        revealedCorrect: question.revealedCorrectAnswer,
        isCorrect: _matchesIdentification(question.revealedCorrectAnswer, answer),
        onChanged: onChanged,
      ),
      QuestionType.essay => _TextAnswer(
        value: answer is String ? answer! as String : '',
        revealed: revealed,
        multiline: true,
        onChanged: onChanged,
      ),
      QuestionType.enumeration => _EnumerationInput(
        itemCount: question.enumerationPoints.length,
        value: answer is List ? (answer! as List).map((Object? e) => '$e').toList() : const [],
        points: question.enumerationPoints,
        onChanged: onChanged,
      ),
      QuestionType.matching => _MatchingInput(
        items: question.matchingItems,
        options: question.matchingOptions,
        value: answer is List ? (answer! as List).map((Object? e) => '$e').toList() : const [],
        onChanged: onChanged,
      ),
    };
  }

  /// Best-effort highlight for identification answers; the server normalises
  /// (case, spacing, accepted variants), so this is indicative only.
  static bool _matchesIdentification(Object? correct, Object? given) {
    if (correct == null || given is! String) return false;
    return '$correct'.trim().toLowerCase() == given.trim().toLowerCase();
  }
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.options,
    required this.selectedIndex,
    required this.revealed,
    required this.onSelect,
  });

  final List<QuestionOption> options;
  final int? selectedIndex;
  final bool revealed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: [
        for (final (int index, QuestionOption option) in options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedIndex == index ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    width: selectedIndex == index ? 2 : 1,
                  ),
                  color: selectedIndex == index ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedIndex == index ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selectedIndex == index ? theme.colorScheme.primary : theme.colorScheme.outline,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(option.text, style: theme.textTheme.bodyMedium)),
                    if (revealed && option.isCorrect == true)
                      const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A text field whose controller is owned by this widget.
///
/// Creating the controller inline in `build` would recreate it on every
/// keystroke-driven rebuild and throw the caret back to position 0 mid-answer,
/// so the controller is created once and only re-synced when the incoming value
/// genuinely differs (a draft loaded from the server, or a cleared answer).
class _SyncedTextField extends StatefulWidget {
  const _SyncedTextField({
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.decoration,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final InputDecoration? decoration;

  @override
  State<_SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<_SyncedTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only overwrite when the parent genuinely disagrees, so typing is not
    // interrupted by the echo of our own onChanged.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      decoration: widget.decoration,
    );
  }
}

class _TextAnswer extends StatelessWidget {
  const _TextAnswer({
    required this.value,
    required this.revealed,
    required this.onChanged,
    this.multiline = false,
    this.revealedCorrect,
    this.isCorrect = false,
  });

  final String value;
  final bool revealed;
  final bool multiline;
  final ValueChanged<Object?> onChanged;
  final Object? revealedCorrect;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SyncedTextField(
          value: value,
          onChanged: onChanged,
          maxLines: multiline ? 8 : 1,
          minLines: multiline ? 4 : 1,
          keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Type your answer…'),
        ),
        if (revealed && revealedCorrect != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: isCorrect ? Colors.green : theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Correct answer: $revealedCorrect',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Enumeration answers are a list of free-text items; the server grades each
/// item independently, so empty rows are simply not sent.
class _EnumerationInput extends StatelessWidget {
  const _EnumerationInput({
    required this.itemCount,
    required this.value,
    required this.points,
    required this.onChanged,
  });

  final int itemCount;
  final List<String> value;
  final List<double> points;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int rows = itemCount == 0 ? 1 : itemCount;

    void update(int index, String text) {
      final List<String> next = List<String>.generate(rows, (int i) => i < value.length ? value[i] : '');
      next[index] = text;
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 8),
                  child: Text('${i + 1}.', style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: _SyncedTextField(
                    value: i < value.length ? value[i] : '',
                    onChanged: (String text) => update(i, text),
                    decoration: InputDecoration(
                      hintText: 'Item ${i + 1}',
                      isDense: true,
                      suffixText: i < points.length ? '${points[i].toStringAsFixed(0)} pts' : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One dropdown per matching prompt. The selected value is the visible answer
/// text, never a hidden index.
class _MatchingInput extends StatelessWidget {
  const _MatchingInput({
    required this.items,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<MatchingItem> items;
  final List<MatchingOption> options;
  final List<String> value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    void update(int index, String? selected) {
      final List<String> next = List<String>.generate(items.length, (int i) => i < value.length ? value[i] : '');
      next[index] = selected ?? '';
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (int index, MatchingItem item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.prompt, style: theme.textTheme.bodyMedium),
                      Text(
                        '${item.points.toStringAsFixed(0)} pts',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: index < value.length && value[index].isNotEmpty ? value[index] : null,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Select…')),
                      for (final MatchingOption option in options)
                        DropdownMenuItem<String>(value: option.value, child: Text(option.text)),
                    ],
                    onChanged: (String? selected) => update(index, selected),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}