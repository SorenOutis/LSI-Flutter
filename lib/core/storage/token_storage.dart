import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum bearer token between launches.
///
/// `flutter_secure_storage` writes to the Keychain on iOS and to
/// AES-GCM/RSA-wrapped Keystore storage on Android, so the token — a full account
/// credential — never lands in plain SharedPreferences where a device backup or
/// a rooted phone could read it.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Android: AES-GCM encrypted values with RSA-wrapped keys is the
            // package default; explicit for readability at the call site.
            aOptions: AndroidOptions(),
            // `first_unlock` keeps the token readable after a reboot once the
            // user has unlocked once, so the app does not bounce to login every
            // time the phone restarts.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );

  static const String _tokenKey = 'lsi.api.token';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      // A corrupt keystore entry must not wedge the app on the splash screen.
      return null;
    }
  }

  Future<void> write(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Best effort: an already-unwritable keystore is not worth surfacing, and
      // the caller has already dropped its in-memory copy.
    }
  }
}