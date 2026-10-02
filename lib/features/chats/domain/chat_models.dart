import 'package:intl/intl.dart';

import '../../../core/utils/json_parsing.dart';

/// One row of `/api/v1/chats` — a persisted conversation, summarised.
///
/// The endpoint never sends message bodies here: `lastMessage` is a preview
/// selected in SQL and `messageCount` a `withCount`, so listing a hundred
/// conversations stays one cheap query. That is also why the list can render
/// before any conversation has been opened.
class ChatSessionSummary {
  const ChatSessionSummary({
    required this.id,
    required this.title,
    this.source,
    required this.messageCount,
    this.lastMessage,
    this.updatedAt,
    this.updatedAtHuman,
  });

  final int id;
  final String title;
  final String? source;
  final int messageCount;
  final String? lastMessage;
  final DateTime? updatedAt;

  /// The server's own `diffForHumans()` ("2 hours ago"), preferred over a local
  /// computation when present so the two never disagree about the same row.
  final String? updatedAtHuman;

  /// A session the student never got past the first message in — the server
  /// names it "New chat" until something is sent.
  bool get isUntitled => title.isEmpty || title == 'New chat';

  String get timeLabel {
    final String? human = updatedAtHuman;
    if (human != null && human.isNotEmpty) return human;

    final DateTime? at = updatedAt;
    if (at == null) return '';

    final Duration age = DateTime.now().difference(at);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    if (age.inDays < 7) return '${age.inDays}d ago';
    return DateFormat.MMMd().format(at);
  }

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummary(
      id: json.asInt('id'),
      title: json.asString('title', fallback: 'New chat'),
      source: json.asStringOrNull('source'),
      messageCount: json.asInt('messageCount'),
      lastMessage: json.asStringOrNull('lastMessage'),
      updatedAt: json.asDateOrNull('updatedAt')?.toLocal(),
      updatedAtHuman: json.asStringOrNull('updatedAtHuman'),
    );
  }
}

/// A page of conversation summaries.
class ChatSessions {
  const ChatSessions({required this.sessions, required this.hasMore});

  final List<ChatSessionSummary> sessions;
  final bool hasMore;

  bool get isEmpty => sessions.isEmpty;

  static const ChatSessions empty = ChatSessions(
    sessions: <ChatSessionSummary>[],
    hasMore: false,
  );

  /// The conversation with [id], or null when the first page does not hold it —
  /// which happens on a deep link into an older thread.
  ChatSessionSummary? byId(int id) {
    for (final ChatSessionSummary session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  factory ChatSessions.fromJson(Map<String, dynamic> json) {
    return ChatSessions(
      sessions: json.asMapList('data').map(ChatSessionSummary.fromJson).toList(growable: false),
      hasMore: json.asMap('meta').asBool('hasMore'),
    );
  }
}

/// One turn in a conversation. `role` is `user` or `assistant`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.thinking,
    this.createdAt,
  });

  final int id;
  final String role;
  final String content;

  /// The assistant's reasoning trace when the provider returned one. Shown
  /// collapsed: it explains the answer, but it is not the answer.
  final String? thinking;

  final DateTime? createdAt;

  bool get isUser => role == 'user';

  bool get hasThinking {
    final String? trace = thinking;
    return trace != null && trace.trim().isNotEmpty;
  }

  String get timeLabel => createdAt == null ? '' : DateFormat.jm().format(createdAt!);

  /// A turn the student has just sent, shown immediately rather than after the
  /// round trip. The server assigns the real id on the next fetch.
  factory ChatMessage.outgoing(String content) =>
      ChatMessage(id: 0, role: 'user', content: content, createdAt: DateTime.now());

  factory ChatMessage.reply(String content) =>
      ChatMessage(id: 0, role: 'assistant', content: content, createdAt: DateTime.now());

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json.asInt('id'),
      role: json.asString('role', fallback: 'assistant'),
      content: json.asString('content'),
      thinking: json.asStringOrNull('thinking'),
      createdAt: json.asDateOrNull('createdAt')?.toLocal(),
    );
  }
}

/// A conversation's turns, oldest first.
///
/// `hasMore` means an older page exists above; the thread screen only asks for
/// more when the student scrolls to the top, so opening a long conversation
/// does not load all of it.
class ChatThread {
  const ChatThread({required this.sessionId, required this.messages, required this.hasMore});

  final int sessionId;
  final List<ChatMessage> messages;
  final bool hasMore;

  bool get isEmpty => messages.isEmpty;

  /// `/chats/{session}/messages` — `{data: [...], meta: {hasMore, nextBeforeId}}`.
  factory ChatThread.fromMessagesPage(int sessionId, Map<String, dynamic> json) {
    return ChatThread(
      sessionId: sessionId,
      messages: json.asMapList('data').map(ChatMessage.fromJson).toList(growable: false),
      hasMore: json.asMap('meta').asBool('hasMore'),
    );
  }
}
