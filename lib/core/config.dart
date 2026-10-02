/// Compile-time configuration.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///
/// 10.0.2.2 is the host loopback as seen from the Android emulator. On a
/// physical device use the machine's LAN address, and on iOS simulator use
/// http://localhost:8000.
///
/// The `/api/v1` suffix is not optional. The Laravel app mounts its
/// Sanctum-token API under that prefix (bootstrap/app.php) because
/// routes/web.php declares colliding bare `/api/*` paths for the Inertia
/// frontend, and Laravel lets the last-registered route win. Repositories here
/// call `/api/...`, so without the version segment every request 404s.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Long enough to ride out a flaky cell connection on an autosave, short
  /// enough that a dead network still surfaces an error rather than hanging the
  /// countdown screen.
  static const Duration connectTimeout = Duration(seconds: 20);

  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Autosave while answering an exam. The server accepts up to 200 answers per
  /// call, so this interval keeps the request count low without risking lost work.
  static const Duration autosaveInterval = Duration(seconds: 20);

  static const Duration examPollInterval = Duration(seconds: 3);

  /// Answer every API call from an in-memory fake instead of the network.
  ///
  /// Off unless explicitly requested, so a normal build can never ship with a
  /// login that silently accepts anything:
  ///   flutter run --dart-define=USE_FAKE_API=true
  static const bool useFakeApi = bool.fromEnvironment('USE_FAKE_API');
}