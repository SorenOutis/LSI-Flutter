import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../../../core/config.dart';
import '../data/exam_repository.dart';
import '../domain/exam_models.dart';

final Provider<ExamRepository> examRepositoryProvider = Provider<ExamRepository>((Ref ref) {
  return ExamRepository(ref.watch(apiClientProvider));
});

/// One cursor page of exam cards, plus the cursor needed for the next page.
///
/// Pages accumulate into a single list so "load more" appends rather than
/// replaces, and the whole catalogue stays alive for the life of the session.
class ExamListState {
  const ExamListState({
    this.groups = const [],
    this.hasMore = false,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<ExamSeasonGroup> groups;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;
  final Object? loadMoreError;

  int get examCount => groups.fold<int>(0, (int sum, ExamSeasonGroup g) => sum + g.exams.length);

  ExamListState copyWith({
    List<ExamSeasonGroup>? groups,
    bool? hasMore,
    String? nextCursor,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return ExamListState(
      groups: groups ?? this.groups,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

final AsyncNotifierProvider<ExamListController, ExamListState> examListProvider =
    AsyncNotifierProvider<ExamListController, ExamListState>(ExamListController.new);

class ExamListController extends AsyncNotifier<ExamListState> {
  @override
  Future<ExamListState> build() async {
    final ExamPage page = await ref.watch(examRepositoryProvider).listExams();
    return ExamListState(groups: page.groups, hasMore: page.hasMore, nextCursor: page.nextCursor);
  }

  /// Re-read from scratch, discarding accumulated pages.
  Future<void> refresh() async {
    state = const AsyncLoading<ExamListState>();
    state = await AsyncValue.guard(() async {
      final ExamPage page = await ref.read(examRepositoryProvider).listExams();
      return ExamListState(groups: page.groups, hasMore: page.hasMore, nextCursor: page.nextCursor);
    });
  }

  /// Append the next cursor page.
  ///
  /// Guarded against double-entry: the scroll listener that calls this can fire
  /// several times before the first request settles, which would otherwise
  /// duplicate a whole page.
  Future<void> loadMore() async {
    final ExamListState? current = state.value;
    final String? cursor = current?.nextCursor;

    if (cursor == null || current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;

    state = AsyncData<ExamListState>(current.copyWith(isLoadingMore: true, clearLoadMoreError: true));

    try {
      final ExamPage page = await ref.read(examRepositoryProvider).listExams(cursor: cursor);

      state = AsyncData<ExamListState>(
        current.copyWith(
          groups: _merge(current.groups, page.groups),
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      // Keep the pages already on screen; a failed "load more" is recoverable
      // by tapping the retry affordance.
      state = AsyncData<ExamListState>(current.copyWith(isLoadingMore: false, loadMoreError: error));
    }
  }

  /// Concatenate pages, keeping group order stable when a season already exists.
  static List<ExamSeasonGroup> _merge(List<ExamSeasonGroup> existing, List<ExamSeasonGroup> incoming) {
    final Map<String, List<ExamCard>> bySeason = <String, List<ExamCard>>{
      for (final ExamSeasonGroup group in existing) group.seasonName: [...group.exams],
    };

    for (final ExamSeasonGroup group in incoming) {
      bySeason.putIfAbsent(group.seasonName, () => <ExamCard>[]).addAll(group.exams);
    }

    return [
      for (final MapEntry<String, List<ExamCard>> entry in bySeason.entries)
        ExamSeasonGroup(seasonName: entry.key, exams: entry.value),
    ];
  }
}

/// Full exam payload: parts, questions, submissions, deadlines and drafts.
final examDetailProvider = AsyncNotifierProvider.family<ExamDetailController, ExamDetail, int>(
  ExamDetailController.new,
);

/// Full exam payload: parts, questions, submissions, deadlines and drafts.
class ExamDetailController extends AsyncNotifier<ExamDetail> {
  ExamDetailController(this.examId);

  final int examId;

  @override
  Future<ExamDetail> build() {
    return ref.watch(examRepositoryProvider).fetchDetail(examId);
  }

  /// Re-read the exam after a submission so parts, drafts and the XP award
  /// reflect what the server now holds.
  Future<void> reload() async {
    state = await AsyncValue.guard(() => ref.read(examRepositoryProvider).fetchDetail(examId));
  }
}

/// Local answer state for one part while it is being taken.
///
/// The server draft is authoritative on open, but the screen owns edits from
/// then on. Autosave pushes the delta; the dirty set is what a resume would lose
/// if the app died between saves, so it is flushed on pause and on submit.
class PartAnswersState {
  const PartAnswersState({
    required this.examId,
    required this.partId,
    required this.questions,
    this.answers = const {},
    this.savedAnswers = const {},
    this.savedAt,
    this.clockStartedAt,
    this.isSaving = false,
    this.saveError,
  });

  final int examId;
  final int partId;
  final List<ExamQuestion> questions;

  /// Everything the student has entered, keyed by 1-based question number.
  final Map<int, Object?> answers;

  /// The subset the server has confirmed, used to compute the autosave delta.
  final Map<int, Object?> savedAnswers;
  final DateTime? savedAt;
  final DateTime? clockStartedAt;
  final bool isSaving;
  final Object? saveError;

  int get answeredCount => answers.values.where(_isAnswered).length;

  int get questionCount => questions.length;

  double get answeredPoints => questions
      .where((ExamQuestion q) => _isAnswered(answers[q.index]))
      .fold<double>(0, (double sum, ExamQuestion q) => sum + q.points);

  double get totalPoints => questions.fold<double>(0, (double sum, ExamQuestion q) => sum + q.points);

  bool get isComplete => questions.isNotEmpty && answeredCount == questionCount;

  Map<int, Object?> get _dirty => {
    for (final MapEntry<int, Object?> entry in answers.entries)
      if (!_sameValue(entry.value, savedAnswers[entry.key])) entry.key: entry.value,
  };

  Map<int, Object?> get dirtyAnswers => _dirty;

  bool get hasUnsavedChanges => _dirty.isNotEmpty;

  /// Mirror of `isBlankAnswer()` server-side: null, empty string and empty list
  /// all count as unanswered, so they must not be counted toward `answeredCount`.
  static bool _isAnswered(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.any((Object? e) => '$e'.trim().isNotEmpty);
    return true;
  }

  /// Deep-enough equality for the value shapes these questions hold: an int
  /// index, a String, or a `List` of Strings.
  static bool _sameValue(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }

  PartAnswersState copyWith({
    Map<int, Object?>? answers,
    Map<int, Object?>? savedAnswers,
    DateTime? savedAt,
    DateTime? clockStartedAt,
    bool? isSaving,
    Object? saveError,
    bool clearError = false,
  }) {
    return PartAnswersState(
      examId: examId,
      partId: partId,
      questions: questions,
      answers: answers ?? this.answers,
      savedAnswers: savedAnswers ?? this.savedAnswers,
      savedAt: savedAt ?? this.savedAt,
      clockStartedAt: clockStartedAt ?? this.clockStartedAt,
      isSaving: isSaving ?? this.isSaving,
      saveError: clearError ? null : (saveError ?? this.saveError),
    );
  }
}

final partAnswersProvider =
    AsyncNotifierProvider.family<PartAnswersController, PartAnswersState, ({int examId, int partId})>(
      PartAnswersController.new,
    );

class PartAnswersController extends AsyncNotifier<PartAnswersState> {
  PartAnswersController(this.arg);

  final ({int examId, int partId}) arg;

  Timer? _autosaveTimer;

  @override
  Future<PartAnswersState> build() async {
    ref.onDispose(() => _autosaveTimer?.cancel());

    final ExamDetail detail = await ref.watch(examDetailProvider(arg.examId).future);
    final ExamPart? part = detail.parts
        .where((ExamPart p) => p.id == arg.partId)
        .firstOrNull;

    if (part == null) {
      throw StateError('This exam part is not part of your assigned set.');
    }

    final AnswerDraft draft = detail.answerDrafts[arg.partId] ?? AnswerDraft.empty();

    return PartAnswersState(
      examId: arg.examId,
      partId: arg.partId,
      questions: part.questions,
      answers: Map<int, Object?>.of(draft.answers),
      savedAnswers: Map<int, Object?>.of(draft.answers),
      savedAt: draft.savedAt?.toLocal(),
      clockStartedAt: detail.deadlineFor(arg.partId),
    );
  }

  /// Record an edit. The autosave timer restarts on every keystroke so a long
  /// answer is not written on every character.
  void answer(int questionNumber, Object? value) {
    final PartAnswersState? current = state.value;
    if (current == null) return;

    final Map<int, Object?> next = Map<int, Object?>.of(current.answers);

    if (value == null) {
      next.remove(questionNumber);
    } else {
      next[questionNumber] = value;
    }

    state = AsyncData<PartAnswersState>(current.copyWith(answers: next, clearError: true));
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(AppConfig.autosaveInterval, () {
      unawaited(save());
    });
  }

  /// Push only what changed.
  ///
  /// A save failure is recorded, not thrown: the student keeps working and the
  /// dirty set survives so the next attempt retries it. Failing loudly here would
  /// interrupt an in-progress exam over a flaky connection.
  Future<bool> save() async {
    _autosaveTimer?.cancel();

    final PartAnswersState? current = state.value;
    if (current == null || !current.hasUnsavedChanges) return true;
    if (current.isSaving) return false;

    final Map<int, Object?> dirty = current.dirtyAnswers;
    state = AsyncData<PartAnswersState>(current.copyWith(isSaving: true, clearError: true));

    try {
      final ExamRepository repository = ref.read(examRepositoryProvider);
      final int answered = await repository.saveAnswers(
        examId: current.examId,
        partId: current.partId,
        changed: dirty,
      );

      final PartAnswersState? after = state.value;
      if (after == null) return false;

      state = AsyncData<PartAnswersState>(
        after.copyWith(
          // Only the keys we sent are marked saved; anything typed during the
          // request stays dirty and is sent by the next save.
          savedAnswers: {...after.savedAnswers, ...dirty},
          savedAt: DateTime.now(),
          isSaving: false,
        ),
      );
      return answered >= 0;
    } catch (error) {
      final PartAnswersState? after = state.value;
      if (after != null) {
        state = AsyncData<PartAnswersState>(after.copyWith(isSaving: false, saveError: error));
      }
      return false;
    }
  }

  /// Start (or resume) the server clock and store the authoritative deadline.
  Future<DateTime?> startClock() async {
    final PartAnswersState? current = state.value;
    if (current == null) return null;

    try {
      final PartClock clock = await ref
          .read(examRepositoryProvider)
          .startPart(examId: current.examId, partId: current.partId);

      if (clock.deadline != null) {
        state = AsyncData<PartAnswersState>(current.copyWith(clockStartedAt: clock.deadline));
      }
      return clock.deadline;
    } catch (_) {
      // Falling back to no countdown is better than blocking the exam: the
      // server still enforces the window on save and submit.
      return null;
    }
  }

  /// Flush pending edits and submit. The write is durable before submit, so the
  /// answers map is sent explicitly rather than trusting the draft.
  Future<SubmitPartResult> submit() async {
    final PartAnswersState? current = state.value;
    if (current == null) {
      throw StateError('This part is not ready to submit.');
    }

    _autosaveTimer?.cancel();
    await save();

    final ExamRepository repository = ref.read(examRepositoryProvider);
    final SubmitPartResult result = await repository.submitPart(
      examId: current.examId,
      partId: current.partId,
      answers: current.answers,
    );

    await ref.read(examDetailProvider(current.examId).notifier).reload();
    return result;
  }
}