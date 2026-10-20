/// Compile-time app configuration.
///
/// Supply values with `--dart-define`, e.g.
/// `flutter run --dart-define=R2_WORKER_URL=https://encore-media.<account>.workers.dev`.
abstract final class AppConfig {
  /// Base URL of the Cloudflare Worker that stores and serves media.
  static const String r2WorkerUrl = String.fromEnvironment(
    'R2_WORKER_URL',
    defaultValue: 'https://encore-media.encore-app2026.workers.dev',
  );
}
