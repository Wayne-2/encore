import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Keeps a signed-in user's session alive for [sessionLength] from login.
///
/// Firebase persists the auth session indefinitely on its own, so the login
/// time is stored locally and checked on launch. Once the window has passed
/// the user is signed out and has to log in again.
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  static const String _loginAtKey = 'session_login_at';

  /// How long a login stays valid.
  static const Duration sessionLength = Duration(hours: 24);

  /// Records the start of a fresh 24-hour session.
  Future<void> markLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_loginAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // The next launch falls back to Firebase's last sign-in time.
    }
  }

  /// Whether the current session is still inside its 24-hour window.
  ///
  /// Expired (or untraceable) sessions are signed out. Existing users who
  /// signed in before this check existed are anchored to Firebase's last
  /// sign-in time instead of being given a fresh window.
  Future<bool> hasValidSession() async {
    if (!AuthService.isAvailable) return false;

    final user = await AuthService.instance.restoreUser();
    if (user == null) return false;

    final prefs = await SharedPreferences.getInstance();
    var startedAt = prefs.getInt(_loginAtKey);

    if (startedAt == null) {
      final lastSignIn = user.metadata.lastSignInTime;
      if (lastSignIn == null || !await _profileExists()) {
        await endSession();
        return false;
      }
      startedAt = lastSignIn.millisecondsSinceEpoch;
      await prefs.setInt(_loginAtKey, startedAt);
    }

    final started = DateTime.fromMillisecondsSinceEpoch(startedAt);
    if (DateTime.now().difference(started) >= sessionLength) {
      await endSession();
      return false;
    }
    return true;
  }

  /// Whether the user finished onboarding (their profile document exists).
  ///
  /// Only used when adopting a session that has no stored login time, so a
  /// sign-up abandoned midway doesn't skip straight into the app.
  Future<bool> _profileExists() async {
    try {
      return await AuthService.instance.currentUserProfile() != null;
    } catch (_) {
      return false;
    }
  }

  /// Signs out and clears the stored login time.
  Future<void> endSession() async {
    if (AuthService.isAvailable) {
      try {
        await AuthService.instance.signOut();
      } catch (_) {
        // Best effort — the local login time is cleared regardless.
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_loginAtKey);
    } catch (_) {
      // Without a signed-in user the stored time is ignored on next launch.
    }
  }
}
