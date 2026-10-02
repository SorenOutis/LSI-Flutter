import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_storage.dart';
import '../../auth/state/auth_providers.dart';
import '../../dashboard/domain/dashboard_data.dart';
import '../../dashboard/state/dashboard_providers.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

final Provider<PreferencesStorage> preferencesStorageProvider = Provider<PreferencesStorage>((Ref ref) {
  return PreferencesStorage();
});

final Provider<SettingsRepository> settingsRepositoryProvider = Provider<SettingsRepository>((Ref ref) {
  return SettingsRepository(
    client: ref.watch(apiClientProvider),
    preferences: ref.watch(preferencesStorageProvider),
  );
});

/// The app's appearance, watched by `MaterialApp`.
///
/// Starts at [AppSettings.defaults] rather than waiting on storage: the app would
/// otherwise paint one frame in the wrong theme on every cold start. The stored
/// choice arrives a moment later and the theme snaps to it.
final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    // Restored once, in the background, so the first frame renders in the
    // system's appearance instead of blocking the splash on a keystore read.
    unawaited(_restore());
    return AppSettings.defaults;
  }

  Future<void> _restore() async {
    try {
      final AppSettings stored = await ref.read(settingsRepositoryProvider).load();
      if (stored != state) state = stored;
    } catch (_) {
      // An unreadable keystore leaves the system theme in place; see the class
      // doc on PreferencesStorage.
    }
  }

  /// Applies immediately and persists behind it: a student who picks Dark in a
  /// sunlit classroom should not have to relaunch to see it.
  Future<void> setThemeMode(ThemeModeOption mode) async {
    if (mode.themeMode == state.themeMode) return;

    state = state.copyWith(themeMode: mode.themeMode);
    await ref.read(settingsRepositoryProvider).save(state);
  }

  /// Device-local reminder toggles. No backend — apply instantly and persist.
  Future<void> setNotifAssignments(bool value) async {
    state = state.copyWith(notifAssignments: value);
    await ref.read(settingsRepositoryProvider).saveNotifications(state);
  }

  Future<void> setNotifGrades(bool value) async {
    state = state.copyWith(notifGrades: value);
    await ref.read(settingsRepositoryProvider).saveNotifications(state);
  }

  Future<void> setNotifStreak(bool value) async {
    state = state.copyWith(notifStreak: value);
    await ref.read(settingsRepositoryProvider).saveNotifications(state);
  }
}

/// Whether the account asks the server to blur its name on leaderboards.
///
/// Read from the dashboard payload rather than cached on the phone: `blur_leaderboard`
/// is an account column the server owns, and the dashboard is already fetched and
/// kept alive by the home tab, so this costs no extra request.
final FutureProvider<bool> leaderboardBlurProvider = FutureProvider<bool>((Ref ref) async {
  final DashboardData? data = ref.watch(dashboardProvider).value;
  if (data == null) return false;

  for (final SectionLeaderboard board in data.sectionLeaderboards) {
    final bool? blurred = board.viewerIsBlurred;
    if (blurred != null) return blurred;
  }

  return false;
});

/// Toggles the account's leaderboard privacy flag.
///
/// The endpoint flips rather than sets, so the value the server returns — not the
/// intent — becomes the state, and a rejected request puts the switch back where
/// it was. The dashboard is invalidated afterwards because it carries the flag on
/// the viewer's own rows.
final AsyncNotifierProvider<LeaderboardBlurController, bool> leaderboardBlurControllerProvider =
    AsyncNotifierProvider<LeaderboardBlurController, bool>(LeaderboardBlurController.new);

class LeaderboardBlurController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.watch(leaderboardBlurProvider.future);
  }

  Future<void> toggle() async {
    final bool previous = state.value ?? false;

    try {
      state = AsyncData<bool>(await ref.read(settingsRepositoryProvider).toggleLeaderboardBlur());
      ref.invalidate(dashboardProvider);
      ref.invalidate(leaderboardBlurProvider);
    } catch (error, stackTrace) {
      state = AsyncData<bool>(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}