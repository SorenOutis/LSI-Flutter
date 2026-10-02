import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsi_flutter/core/theme/app_theme.dart';
import 'package:lsi_flutter/features/auth/domain/app_user.dart';
import 'package:lsi_flutter/features/auth/presentation/login_screen.dart';
import 'package:lsi_flutter/features/auth/state/auth_providers.dart';
import 'package:lsi_flutter/shared/widgets/common.dart';

void main() {
  testWidgets('login screen renders its fields and validates empty input', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // The session controller would otherwise try to reach the network; the
        // login screen does not read it.
        overrides: [sessionProvider.overrideWith(() => FakeSessionController())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('empty view shows its title and message', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: EmptyView(title: 'Nothing here', message: 'Check back later.'),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Check back later.'), findsOneWidget);
  });
}

/// A session controller that never touches the network.
class FakeSessionController extends SessionController {
  @override
  Future<AppUser?> build() async => null;
}