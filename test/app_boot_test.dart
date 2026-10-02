import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsi_flutter/features/auth/domain/app_user.dart';
import 'package:lsi_flutter/features/auth/presentation/login_screen.dart';
import 'package:lsi_flutter/features/auth/state/auth_providers.dart';
import 'package:lsi_flutter/main.dart';

void main() {
  testWidgets('app boots to the login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(FakeSessionController.new)],
        child: const LsiApp(),
      ),
    );

    // Explicit pumps rather than pumpAndSettle: google_fonts resolves its font
    // download asynchronously, so the tree never reaches a fully quiescent
    // frame in a test environment.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

/// A session controller that resolves immediately without touching the network.
class FakeSessionController extends SessionController {
  FakeSessionController({this.user});

  final AppUser? user;

  @override
  Future<AppUser?> build() async => user;
}