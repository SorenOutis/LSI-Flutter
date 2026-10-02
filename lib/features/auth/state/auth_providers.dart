import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final Provider<TokenStorage> tokenStorageProvider = Provider<TokenStorage>((Ref ref) {
  return TokenStorage();
});

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
});

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepository(client: ref.watch(apiClientProvider), tokenStorage: ref.watch(tokenStorageProvider));
});

/// The signed-in user, or null when signed out.
///
/// `AsyncLoading` means "we have not yet asked the server whether the stored
/// token is still good" — the router holds on the splash screen for exactly
/// that state, so a returning user never sees the login form flash past.
final AsyncNotifierProvider<SessionController, AppUser?> sessionProvider =
    AsyncNotifierProvider<SessionController, AppUser?>(SessionController.new);

class SessionController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final AuthRepository repository = ref.watch(authRepositoryProvider);

    try {
      return await repository.restoreSession();
    } on ApiException catch (error) {
      // A dead token is the normal "signed out" case, not a failure worth
      // showing. Anything else (no network, server down) is surfaced so the
      // user can retry instead of being silently logged out.
      if (error.isUnauthorized) return null;
      rethrow;
    }
  }

  void adopt(AppUser user) => state = AsyncData<AppUser?>(user);

  Future<void> signOut() async {
    final AuthRepository repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AsyncData<AppUser?>(null);
  }

  /// Called when any request comes back 401. Clears state without a second
  /// logout round-trip: the token is already gone by the time this fires.
  void handleUnauthorized() {
    if (state.value == null) return;
    state = const AsyncData<AppUser?>(null);
  }
}

/// Form-level state for the login screen.
///
/// Kept separate from [sessionProvider] so that submitting a form shows a
/// spinner on the button without putting the whole app back into
/// [AsyncLoading] and bouncing the router to the splash screen.
final AsyncNotifierProvider<LoginController, void> loginControllerProvider =
    AsyncNotifierProvider<LoginController, void>(LoginController.new);

class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> submit({required String email, required String password}) async {
    state = const AsyncLoading<void>();
    try {
      final AuthSession session = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      ref.read(sessionProvider.notifier).adopt(session.user);
      state = const AsyncData<void>(null);
      return true;
    } on ApiException catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return false;
    }
  }
}

/// Form-level state for the registration screen.
final AsyncNotifierProvider<RegisterController, void> registerControllerProvider =
    AsyncNotifierProvider<RegisterController, void>(RegisterController.new);

class RegisterController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> submit({
    required String firstName,
    required String lastName,
    String? middleName,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final AuthSession session = await ref
          .read(authRepositoryProvider)
          .register(
            firstName: firstName,
            lastName: lastName,
            middleName: middleName,
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation,
          );
      ref.read(sessionProvider.notifier).adopt(session.user);
      state = const AsyncData<void>(null);
      return true;
    } on ApiException catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return false;
    }
  }
}