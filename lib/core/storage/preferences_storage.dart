import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local preferences that belong to the phone rather than the account.
///
/// `flutter_secure_storage` is the one key/value store this project already
/// depends on, so the appearance choice lives here instead of pulling in
/// `shared_preferences` for a single string. Nothing kept here is a secret; the
/// keys are namespaced apart from the auth token so signing out — which clears
/// the token — never resets them.
///
/// Every call is failure-tolerant. A device with an unreadable keystore should
/// start the app on the system theme, not refuse to start.
class PreferencesStorage {
  PreferencesStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _themeModeKey = 'lsi.pref.themeMode';

  /// Device-local notification toggles (design-first, no backend yet).
  /// Stored here — not on the account — so they apply instantly and work offline.
  static const String _notifAssignmentsKey = 'lsi.pref.notif.assignments';
  static const String _notifGradesKey = 'lsi.pref.notif.grades';
  static const String _notifStreakKey = 'lsi.pref.notif.streak';

  final FlutterSecureStorage _storage;

  /// The stored appearance, or null when nothing has been chosen yet.
  Future<String?> readThemeMode() async {
    try {
      return await _storage.read(key: _themeModeKey);
    } catch (_) {
      return null;
    }
  }

  /// Best effort: if the write fails the choice still applies to this session.
  Future<void> writeThemeMode(String value) async {
    try {
      await _storage.write(key: _themeModeKey, value: value);
    } catch (_) {
      // Ignored on purpose — see the class doc.
    }
  }

  /// Notification prefs, defaulting to on when nothing stored yet.
  Future<bool> readNotif(String key, {bool fallback = true}) async {
    try {
      final String? raw = await _storage.read(key: key);
      if (raw == null) return fallback;
      return raw == '1' || raw.toLowerCase() == 'true';
    } catch (_) {
      return fallback;
    }
  }

  Future<void> writeNotif(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value ? '1' : '0');
    } catch (_) {
      // Best effort like theme mode.
    }
  }

  static String get notifAssignmentsKey => _notifAssignmentsKey;
  static String get notifGradesKey => _notifGradesKey;
  static String get notifStreakKey => _notifStreakKey;
}
