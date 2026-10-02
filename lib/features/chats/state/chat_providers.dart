import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

final Provider<ChatRepository> chatRepositoryProvider = Provider<ChatRepository>((Ref ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

/// `/api/v1/chats` — the conversation list.
///
/// Kept alive rather than auto-disposed: it is one small request, and the thread
/// screen reads its conversation title from this list instead of carrying the
/// title through the route.
final FutureProvider<ChatSessions> chatSessionsProvider = FutureProvider<ChatSessions>((Ref ref) async {
  return ref.watch(chatRepositoryProvider).fetchSessions();
});

/// One conversation, keyed by session id.
///
/// Auto-disposed so leaving a thread releases its message bodies instead of
/// holding every conversation the student ever opened.
final chatThreadProvider = AsyncNotifierProvider.autoDispose
    .family<ChatThreadController, ChatThread, int>(ChatThreadController.new);

class ChatThreadController extends AsyncNotifier<ChatThread> {
  ChatThreadController(this.sessionId);

  final int sessionId;

  @override
  Future<ChatThread> build() {
    return ref.watch(chatRepositoryProvider).fetchThread(sessionId);
  }

  /// Append a turn the server has already persisted, so the conversation reads
  /// correctly without re-fetching and losing the student's place in it.
  void append(ChatMessage message) {
    final ChatThread? current = state.value;
    if (current == null) return;

    state = AsyncData<ChatThread>(
      ChatThread(
        sessionId: current.sessionId,
        messages: <ChatMessage>[...current.messages, message],
        hasMore: current.hasMore,
      ),
    );
  }

  /// Prepend an older page fetched via `before_id`. Returns false when the
  /// server has nothing older.
  Future<bool> loadMore() async {
    final ChatThread? current = state.value;
    if (current == null || !current.hasMore || current.messages.isEmpty) return false;

    final int oldestId = current.messages.first.id;
    if (oldestId <= 0) return false;

    final ChatThread page =
        await ref.read(chatRepositoryProvider).fetchThread(sessionId, beforeId: oldestId);
    if (page.messages.isEmpty) {
      state = AsyncData<ChatThread>(
        ChatThread(sessionId: sessionId, messages: current.messages, hasMore: false),
      );
      return false;
    }

    state = AsyncData<ChatThread>(
      ChatThread(
        sessionId: sessionId,
        messages: <ChatMessage>[...page.messages, ...current.messages],
        hasMore: page.hasMore,
      ),
    );
    return page.hasMore;
  }

  /// Drop a turn that was only shown optimistically, when its send failed.
  /// Matched by identity, so a repeated message never removes the wrong one.
  void retract(ChatMessage message) {
    final ChatThread? current = state.value;
    if (current == null) return;

    final List<ChatMessage> remaining = <ChatMessage>[...current.messages]..remove(message);
    state = AsyncData<ChatThread>(
      ChatThread(
        sessionId: current.sessionId,
        messages: remaining,
        hasMore: current.hasMore,
      ),
    );
  }
}

/// Sending state for one conversation.
///
/// Deliberately separate from [chatThreadProvider]: a send must not push the
/// thread back into `AsyncLoading`, or every message the student can currently
/// read would be replaced by a skeleton while the reply is generated.
final chatComposerProvider = AsyncNotifierProvider.autoDispose
    .family<ChatComposer, void, int>(ChatComposer.new);

class ChatComposer extends AsyncNotifier<void> {
  ChatComposer(this.sessionId);

  final int sessionId;

  @override
  FutureOr<void> build() {}

  /// Sends one turn and returns the assistant's reply, or null when the send
  /// failed — in which case [state] carries the error and the caller puts the
  /// draft back in the composer rather than losing what the student typed.
  Future<String?> send(String message) async {
    state = const AsyncLoading<void>();

    try {
      final String reply = await ref.read(chatRepositoryProvider).send(sessionId, message);
      state = const AsyncData<void>(null);
      return reply;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return null;
    }
  }
}

/// Design-first new chat: creates the session then the list refreshes.
///
/// Returns the new session id so the UI can push the thread immediately.
final AsyncNotifierProvider<NewChatController, int?> newChatControllerProvider =
    AsyncNotifierProvider<NewChatController, int?>(NewChatController.new);

class NewChatController extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() => null;

  Future<int> create({String? title, String? firstMessage}) async {
    state = const AsyncLoading<int?>();
    try {
      final int id = await ref
          .read(chatRepositoryProvider)
          .createSession(title: title, firstMessage: firstMessage);
      state = AsyncData<int?>(id);
      ref.invalidate(chatSessionsProvider);
      return id;
    } catch (error, stackTrace) {
      state = AsyncError<int?>(error, stackTrace);
      rethrow;
    }
  }
}

/// Design-first delete + rename (fake-backed; real API later).
final AsyncNotifierProvider<ChatSessionActionsController, void> chatSessionActionsProvider =
    AsyncNotifierProvider<ChatSessionActionsController, void>(ChatSessionActionsController.new);

class ChatSessionActionsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> remove(int sessionId) async {
    await ref.read(chatRepositoryProvider).deleteSession(sessionId);
    ref.invalidate(chatSessionsProvider);
  }

  Future<void> rename(int sessionId, String title) async {
    await ref.read(chatRepositoryProvider).renameSession(sessionId, title);
    ref.invalidate(chatSessionsProvider);
  }
}
