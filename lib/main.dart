import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/state/auth_providers.dart';
import 'features/settings/state/settings_providers.dart';
import 'routing/app_router.dart';

void main() {
  runApp(const ProviderScope(child: LsiApp()));
}

class LsiApp extends ConsumerStatefulWidget {
  const LsiApp({super.key});

  @override
  ConsumerState<LsiApp> createState() => _LsiAppState();
}

class _LsiAppState extends ConsumerState<LsiApp> {
  @override
  void initState() {
    super.initState();

    // One place handles token expiry for the whole app: the ApiClient clears the
    // stored token on any 401 and calls this, which drops the session and lets
    // the router's redirect send the user to /login.
    ref.read(apiClientProvider).onUnauthorized = () {
      ref.read(sessionProvider.notifier).handleUnauthorized();
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LSI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Read here rather than in the screens: appearance is an app-wide choice,
      // and letting each page decide would let two tabs disagree.
      themeMode: ref.watch(settingsProvider).themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}