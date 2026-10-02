import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/json_parsing.dart';
import '../domain/app_user.dart';

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AppUser user;
  final String token;
}

/// Token-based authentication against `/api/auth/*`.
///
/// The token is written to the keystore/keychain *before* the user is considered
/// signed in, so an app kill immediately after login cannot leave the UI showing
/// a logged-in shell with no credential behind it.
class AuthRepository {
  AuthRepository({required this._client, required this.tokenStorage});

  final ApiClient _client;
  final TokenStorage tokenStorage;

  Future<String?> readToken() => tokenStorage.read();

  Future<void> persistToken(String token) => tokenStorage.write(token);

  Future<AuthSession> login({required String email, required String password}) async {
    final Map<String, dynamic> json = await _client.postJson(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );

    return _sessionFrom(json);
  }

  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    String? middleName,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final Map<String, dynamic> json = await _client.postJson(
      '/auth/register',
      body: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        if (middleName != null && middleName.trim().isNotEmpty) 'middle_name': middleName.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'terms': true,
      },
    );

    return _sessionFrom(json);
  }

  /// Confirm a stored token is still valid and refresh the cached profile.
  ///
  /// Returns null when the token is missing, expired, or the account is gone,
  /// which is the signal to clear storage and show the login screen.
  Future<AppUser?> restoreSession() async {
    final String? token = await tokenStorage.read();
    if (token == null || token.isEmpty) return null;

    final Map<String, dynamic> json = await _client.getJson('/user');
    return AppUser.fromJson(json);
  }

  /// Revoke the token server-side.
  ///
  /// A failure here is swallowed on purpose: the user asked to sign out, the
  /// local token is being deleted either way, and reporting a network error
  /// would leave them stuck on the screen they tried to leave.
  Future<void> logout() async {
    try {
      await _client.postJson('/auth/logout');
    } catch (_) {
      // Best effort.
    } finally {
      await tokenStorage.clear();
    }
  }

  Future<AuthSession> _sessionFrom(Map<String, dynamic> json) async {
    final String token = json['token'] as String? ?? '';
    if (token.isEmpty) {
      throw const FormatException('The server did not return a session token.');
    }

    await tokenStorage.write(token);
    return AuthSession(user: AppUser.fromJson(json.asMap('user')), token: token);
  }
}