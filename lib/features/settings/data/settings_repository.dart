import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../core/utils/json_parsing.dart';
import '../domain/app_settings.dart';

/// Everything Settings can read or write.
///
/// Two storage tiers on purpose. The appearance choice belongs to the phone, so
/// it goes through [PreferencesStorage] and applies without a round trip. The
/// leaderboard privacy toggle is an account setting the server owns, so it goes
/// through the API even though the app would happily fake it locally.
class SettingsRepository {
  const SettingsRepository({required this.client, required this.preferences});

  final ApiClient client;
  final PreferencesStorage preferences;

  Future<AppSettings> load() async {
    final String? theme = await preferences.readThemeMode();
    return AppSettings(
      themeMode: AppSettings.fromPersistedThemeMode(theme).themeMode,
      notifAssignments: await preferences.readNotif(PreferencesStorage.notifAssignmentsKey),
      notifGrades: await preferences.readNotif(PreferencesStorage.notifGradesKey),
      notifStreak: await preferences.readNotif(PreferencesStorage.notifStreakKey),
    );
  }

  Future<void> save(AppSettings settings) {
    return preferences.writeThemeMode(settings.persistedThemeMode);
  }

  Future<void> saveNotifications(AppSettings settings) async {
    await preferences.writeNotif(PreferencesStorage.notifAssignmentsKey, settings.notifAssignments);
    await preferences.writeNotif(PreferencesStorage.notifGradesKey, settings.notifGrades);
    await preferences.writeNotif(PreferencesStorage.notifStreakKey, settings.notifStreak);
  }

  /// `POST /leaderboard/toggle-blur`.
  ///
  /// The route has no "set to" form — it flips the account's `blur_leaderboard`
  /// and returns the resulting value, so the server's answer is the only state
  /// the client should adopt. Optimistically assuming the new value would let a
  /// rejected request leave the switch disagreeing with every board.
  Future<bool> toggleLeaderboardBlur() async {
    final Map<String, dynamic> json = await client.postJson('/leaderboard/toggle-blur');
    return json.asBool('blur_leaderboard');
  }
}