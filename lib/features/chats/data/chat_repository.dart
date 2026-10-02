import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parsing.dart';
import '../domain/chat_models.dart';

/// The Chats endpoints: the conversation list, one thread, and sending a turn.
///
/// Sending is the only write. The server persists both the student's message and
/// the assistant's reply in one call and answers with the reply text plus the
/// refreshed session, so there is no separate "save" step for the client to lose.
class ChatRepository {
  const ChatRepository(this._client);

  final ApiClient _client;

  Future<ChatSessions> fetchSessions({String? cursor}) async {
    final Map<String, dynamic> json = await _client.getJson(
      '/chats',
      query: <String, dynamic>{if (cursor != null && cursor.isNotEmpty) 'cursor': cursor},
    );
    return ChatSessions.fromJson(json);
  }

  /// The newest 80 turns, or the 80 above [beforeId] when paging back.
  Future<ChatThread> fetchThread(int sessionId, {int? beforeId}) async {
    final Map<String, dynamic> json = await _client.getJson(
      '/chats/$sessionId/messages',
      query: <String, dynamic>{'before_id': ?beforeId},
    );
    return ChatThread.fromMessagesPage(sessionId, json);
  }

  /// Send one turn and return the assistant's reply.
  ///
  /// A 200 with a body is not guaranteed to be an answer — the server also uses
  /// this route to deliver the daily-cap and guardrail notices — so the text is
  /// returned as-is and rendered as a normal assistant turn.
  Future<String> send(int sessionId, String message) async {
    final Map<String, dynamic> json = await _client.postJson(
      '/chats/$sessionId/messages',
      body: <String, dynamic>{'message': message},
    );

    final String reply = json.asString('response');
    if (reply.trim().isEmpty) {
      return 'Echo did not return an answer. Try asking again.';
    }
    return reply;
  }

  /// Design-first create: `POST /chats {title?, message?}`.
  /// Returns the new session id. Backend later persists source=history.
  Future<int> createSession({String? title, String? firstMessage}) async {
    final Map<String, dynamic> json = await _client.postJson(
      '/chats',
      body: <String, dynamic>{
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (firstMessage != null && firstMessage.trim().isNotEmpty) 'message': firstMessage.trim(),
      },
    );
    return json.asInt('id');
  }

  /// Design-first delete + rename (fake supports both; real API later).
  Future<void> deleteSession(int sessionId) async {
    await _client.deleteJson('/chats/$sessionId');
  }

  Future<String> renameSession(int sessionId, String title) async {
    final Map<String, dynamic> json = await _client.patchJson(
      '/chats/$sessionId',
      body: <String, dynamic>{'title': title.trim()},
    );
    return json.asString('title', fallback: title.trim());
  }
}
