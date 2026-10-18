/// Compile-time app configuration.
///
/// Supply values with `--dart-define`, e.g.
/// `flutter run --dart-define=R2_WORKER_URL=https://encore-media.<account>.workers.dev`.
abstract final class AppConfig {
  /// Base URL of the Cloudflare Worker that signs uploads and serves media.
  ///
  /// Upload responses already contain absolute public URLs, so this is only
  /// needed to sign new uploads.
  static const String r2WorkerUrl = String.fromEnvironment(
    'R2_WORKER_URL',
    defaultValue: 'https://encore-media.encore-app2026.workers.dev',
  );
}
