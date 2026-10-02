import 'package:flutter/material.dart' show ThemeMode;

/// The three appearance choices offered in Settings.
enum ThemeModeOption {
  system(ThemeMode.system, 'System'),
  light(ThemeMode.light, 'Light'),
  dark(ThemeMode.dark, 'Dark');

  const ThemeModeOption(this.themeMode, this.label);

  final ThemeMode themeMode;
  final String label;
}

/// The device-local half of Settings.
///
/// Only choices this app can actually honour live here. Anything the server owns
/// — the leaderboard privacy toggle, the account itself — is edited through its
/// own endpoint and is deliberately not mirrored into a local flag that could
/// drift out of step with the server.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notifAssignments = true,
    this.notifGrades = true,
    this.notifStreak = true,
  });

  final ThemeMode themeMode;

  /// Device-local reminder toggles. No backend yet — they gate local
  /// reminders only and are safe to flip offline.
  final bool notifAssignments;
  final bool notifGrades;
  final bool notifStreak;

  static const AppSettings defaults = AppSettings();

  ThemeModeOption get option => switch (themeMode) {
    ThemeMode.light => ThemeModeOption.light,
    ThemeMode.dark => ThemeModeOption.dark,
    ThemeMode.system => ThemeModeOption.system,
  };

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notifAssignments,
    bool? notifGrades,
    bool? notifStreak,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notifAssignments: notifAssignments ?? this.notifAssignments,
      notifGrades: notifGrades ?? this.notifGrades,
      notifStreak: notifStreak ?? this.notifStreak,
    );
  }

  /// `ThemeMode.name` is stable across releases ("system"/"light"/"dark"), which
  /// makes it safe to persist and re-read; the index would not be.
  String get persistedThemeMode => themeMode.name;

  static AppSettings fromPersistedThemeMode(String? stored) {
    return switch (stored) {
      'light' => AppSettings(themeMode: ThemeMode.light),
      'dark' => AppSettings(themeMode: ThemeMode.dark),
      _ => AppSettings(themeMode: ThemeMode.system),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.notifAssignments == notifAssignments &&
      other.notifGrades == notifGrades &&
      other.notifStreak == notifStreak;

  @override
  int get hashCode => Object.hash(themeMode, notifAssignments, notifGrades, notifStreak);
}