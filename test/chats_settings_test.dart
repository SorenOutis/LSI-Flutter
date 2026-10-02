import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsi_flutter/core/network/api_client.dart';
import 'package:lsi_flutter/core/network/api_exception.dart';
import 'package:lsi_flutter/core/network/fake/fake_api_adapter.dart';
import 'package:lsi_flutter/core/storage/preferences_storage.dart';
import 'package:lsi_flutter/core/storage/token_storage.dart';
import 'package:lsi_flutter/core/theme/app_theme.dart';
import 'package:lsi_flutter/features/auth/domain/app_user.dart';
import 'package:lsi_flutter/features/auth/state/auth_providers.dart';
import 'package:lsi_flutter/features/chats/data/chat_repository.dart';
import 'package:lsi_flutter/features/chats/domain/chat_models.dart';
import 'package:lsi_flutter/features/chats/presentation/chat_thread_screen.dart';
import 'package:lsi_flutter/features/chats/presentation/chats_screen.dart';
import 'package:lsi_flutter/features/chats/state/chat_providers.dart';
import 'package:lsi_flutter/features/settings/data/settings_repository.dart';
import 'package:lsi_flutter/features/settings/domain/app_settings.dart';
import 'package:lsi_flutter/features/settings/presentation/settings_screen.dart';
import 'package:lsi_flutter/features/settings/state/settings_providers.dart';

/// Keeps the token in memory; the real one needs a platform keystore.
class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// An in-memory stand-in for the secure keystore, so persistence can be asserted
/// without a platform channel.
class _MemoryPreferences extends PreferencesStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> readThemeMode() async => values['lsi.pref.themeMode'];

  @override
  Future<void> writeThemeMode(String value) async => values['lsi.pref.themeMode'] = value;
}

/// The fake backend behind the real client, so repositories and parsing are on
/// the path exactly as they are in the app.
ApiClient _client() {
  final ApiClient client = ApiClient(tokenStorage: _MemoryTokenStorage(), dio: Dio());
  client.raw.httpClientAdapter = FakeApiAdapter();
  return client;
}

class _FakeSession extends SessionController {
  @override
  Future<AppUser?> build() async => const AppUser(
    id: 1,
    publicId: 'LSI-2026-0001',
    name: 'Juan Dela Cruz',
    email: 'student@lsi.test',
    level: 12,
    currentStreak: 7,
    exp: 2480,
  );
}

/// Pins one conversation so the thread page renders without a request.
///
/// The family controller takes its session id as a constructor argument, so an
/// override has to match that shape rather than being a plain async closure.
class _FixedThread extends ChatThreadController {
  _FixedThread() : super(1);

  @override
  Future<ChatThread> build() async => _pinnedThread!;
}

/// Set once in the rendering group's `setUpAll`.
ChatThread? _pinnedThread;

SettingsRepository _settingsRepository() {
  return SettingsRepository(client: _client(), preferences: _MemoryPreferences());
}

void main() {
  group('chats payloads', () {
    late ApiClient client;

    setUp(() => client = _client());

    test('sessions parse summaries, counts and previews', () async {
      final ChatSessions data = await ChatRepository(client).fetchSessions();

      expect(data.sessions, isNotEmpty);
      expect(data.hasMore, isFalse);

      final ChatSessionSummary newest = data.sessions.first;
      expect(newest.title, isNotEmpty);
      expect(newest.messageCount, greaterThan(0));
      expect(newest.lastMessage, isNotNull);
      // A relative label the list can show without re-deriving the server's.
      expect(newest.timeLabel, isNotEmpty);

      // Newest first.
      final List<DateTime> times = data.sessions
          .map((ChatSessionSummary s) => s.updatedAt!)
          .toList(growable: false);
      expect(
        times,
        orderedEquals(<DateTime>[...times]..sort((DateTime a, DateTime b) => b.compareTo(a))),
      );

      expect(data.byId(newest.id), isNotNull);
      expect(data.byId(-1), isNull);
    });

    test('a thread parses both roles and the reasoning trace', () async {
      final ChatThread thread = await ChatRepository(client).fetchThread(1);

      expect(thread.sessionId, 1);
      expect(thread.isEmpty, isFalse);
      // Oldest first, so a list can render them in order.
      expect(thread.messages.first.isUser, isTrue);
      expect(thread.messages.any((ChatMessage m) => !m.isUser), isTrue);
      expect(thread.messages.any((ChatMessage m) => m.hasThinking), isTrue);

      for (final ChatMessage message in thread.messages) {
        expect(message.createdAt, isNotNull);
      }
    });

    test('an empty conversation parses to an empty thread', () async {
      final ChatThread thread = await ChatRepository(client).fetchThread(4);

      expect(thread.isEmpty, isTrue);
      expect(thread.hasMore, isFalse);
    });

    test('sending persists both halves of the exchange', () async {
      final ChatRepository repository = ChatRepository(client);
      final ChatThread before = await repository.fetchThread(2);

      final String reply = await repository.send(2, 'Can you explain the chain rule?');

      expect(reply, isNotEmpty);
      // Not an echo of what was typed — a mirror would make the thread read as
      // broken rather than answered.
      expect(reply.toLowerCase().contains('chain rule'), isFalse);

      final ChatThread after = await repository.fetchThread(2);
      expect(after.messages.length, before.messages.length + 2);
      expect(after.messages.last.isUser, isFalse);
      expect(after.messages[after.messages.length - 2].content, 'Can you explain the chain rule?');
    });

    test('the session list reflects a message just sent', () async {
      final ChatRepository repository = ChatRepository(client);
      final ChatSessionSummary summaryBefore = (await repository.fetchSessions()).byId(3)!;

      await repository.send(3, 'Explain eigenvalues simply');

      final ChatSessionSummary after = (await repository.fetchSessions()).byId(3)!;
      // The preview and the count both move, or the list would show a stale row
      // after the student returns from the thread.
      expect(after.messageCount, summaryBefore.messageCount + 2);
      expect(after.lastMessage, isNot(summaryBefore.lastMessage));
    });

    test('an unknown conversation is a 404, not an empty thread', () async {
      // Silently returning no messages would read as an empty conversation
      // rather than a broken link.
      expect(() => ChatRepository(client).fetchThread(999), throwsA(isA<ApiException>()));
    });
  });

  group('settings', () {
    test('the theme choice round-trips through storage', () async {
      final _MemoryPreferences preferences = _MemoryPreferences();
      final SettingsRepository repository = SettingsRepository(
        client: _client(),
        preferences: preferences,
      );

      expect((await repository.load()).themeMode, ThemeMode.system);

      await repository.save(const AppSettings(themeMode: ThemeMode.dark));

      expect((await repository.load()).themeMode, ThemeMode.dark);
      // Persisted by name, not index, so a future option cannot shift it.
      expect(await preferences.readThemeMode(), 'dark');
    });

    test('an unrecognised stored value falls back to the system theme', () {
      expect(AppSettings.fromPersistedThemeMode('sepia').themeMode, ThemeMode.system);
      expect(AppSettings.fromPersistedThemeMode(null).themeMode, ThemeMode.system);
    });

    test('toggling leaderboard blur adopts the value the server returns', () async {
      final SettingsRepository repository = _settingsRepository();

      expect(await repository.toggleLeaderboardBlur(), isTrue);
      // The route flips rather than sets, so the second call has to go back.
      expect(await repository.toggleLeaderboardBlur(), isFalse);
    });
  });

  group('rendering', () {
    late ChatSessions sessions;
    late ChatThread thread;

    setUpAll(() async {
      final ApiClient client = _client();
      sessions = await ChatRepository(client).fetchSessions();
      thread = await ChatRepository(client).fetchThread(1);
      _pinnedThread = thread;
    });

    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_FakeSession.new),
            apiClientProvider.overrideWith((Ref ref) => _client()),
            preferencesStorageProvider.overrideWith((Ref ref) => _MemoryPreferences()),
            chatSessionsProvider.overrideWith((Ref ref) async => sessions),
            chatThreadProvider(1).overrideWith(_FixedThread.new),
            // The privacy switch reads the dashboard payload in the app; here it
            // is pinned so the page does not depend on a second endpoint.
            leaderboardBlurProvider.overrideWith((Ref ref) async => false),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: page),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // A layout fault is what blanked the dashboard, so every new page is
      // checked for one rather than only for the text it should show.
      expect(tester.takeException(), isNull);
    }

    testWidgets('chats list shows the assistant and the conversations', (WidgetTester tester) async {
      await pumpPage(tester, const ChatsScreen());

      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Echo'), findsOneWidget);
      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('Derivatives practice'), findsOneWidget);
    });

    testWidgets('a thread renders both sides of the conversation', (WidgetTester tester) async {
      await pumpPage(tester, const ChatThreadScreen(sessionId: 1));

      // The composer is the student's way into the thread; without it the page
      // is read-only.
      expect(find.text('Ask Echo a question'), findsOneWidget);
      expect(find.byTooltip('Send'), findsOneWidget);
      // A turn the student sent.
      expect(find.textContaining('product rule'), findsWidgets);
    });

    testWidgets('settings offers a theme choice, a privacy switch and sign out', (WidgetTester tester) async {
      await pumpPage(tester, const SettingsScreen());

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Hide my name on leaderboards'), findsOneWidget);
      // New sections push Sign out below the fold on a 900px viewport —
      // scroll the page list (not the whole app) until it builds.
      final Finder pageList = find.byType(ListView).first;
      for (int attempt = 0; attempt < 10 && find.text('Sign out').evaluate().isEmpty; attempt++) {
        await tester.drag(pageList, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      expect(find.text('Sign out'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Every row is live; a "Soon" chip here would promise a switch that does
      // nothing when tapped.
      expect(find.text('Soon'), findsNothing);
    });
  });
}