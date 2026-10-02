import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lsi_flutter/core/network/api_client.dart';
import 'package:lsi_flutter/core/network/fake/fake_api_adapter.dart';
import 'package:lsi_flutter/core/storage/preferences_storage.dart';
import 'package:lsi_flutter/core/storage/token_storage.dart';
import 'package:lsi_flutter/core/theme/app_theme.dart';
import 'package:lsi_flutter/features/auth/domain/app_user.dart';
import 'package:lsi_flutter/features/auth/state/auth_providers.dart';
import 'package:lsi_flutter/features/settings/state/settings_providers.dart';
import 'package:lsi_flutter/routing/app_router.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

class _MemoryPreferences extends PreferencesStorage {
  @override
  Future<String?> readThemeMode() async => null;

  @override
  Future<void> writeThemeMode(String value) async {}
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

ApiClient _client() {
  final ApiClient client = ApiClient(tokenStorage: _MemoryTokenStorage(), dio: Dio());
  client.raw.httpClientAdapter = FakeApiAdapter();
  return client;
}

/// Drives the real route table with the real feature providers.
///
/// Everything else in the suite overrides the provider a page reads, which is
/// right for testing that page's markup but says nothing about whether the route
/// that shows it exists, or whether pushing it lands anywhere.
Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final ProviderContainer container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(_FakeSession.new),
      apiClientProvider.overrideWith((Ref ref) => _client()),
      preferencesStorageProvider.overrideWith((Ref ref) => _MemoryPreferences()),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = container.read(routerProvider);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );

  return router;
}

void main() {
  testWidgets('the More tab opens Chats and its thread', (WidgetTester tester) async {
    final GoRouter router = await _pumpRouter(tester);

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('More'), findsOneWidget);

    router.go('/more/chats');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Echo'), findsOneWidget);
    expect(find.text('Derivatives practice'), findsOneWidget);

    router.go('/more/chats/1');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // The composer is only here if the thread route resolved to a real screen.
    expect(find.text('Ask Echo a question'), findsOneWidget);
  });

  testWidgets('the More tab opens Settings', (WidgetTester tester) async {
    final GoRouter router = await _pumpRouter(tester);

    await tester.pumpAndSettle(const Duration(seconds: 1));

    router.go('/more/settings');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Hide my name on leaderboards'), findsOneWidget);
  });

  testWidgets('the More tab opens the profile', (WidgetTester tester) async {
    final GoRouter router = await _pumpRouter(tester);

    await tester.pumpAndSettle(const Duration(seconds: 1));

    router.go('/more/profile');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    // The standing rows come from the leaderboard payload the app already holds.
    expect(find.text('STANDING'), findsOneWidget);
  });
}