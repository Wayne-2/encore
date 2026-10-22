import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Where the app should send the user when it launches.
///
/// A Firebase session alone is not enough to enter the app: the email must be
/// verified and onboarding must be finished.
enum SessionStartup {
  /// No signed-in user (or the 24-hour session window has expired).
  signedOut,

  /// Signed in, but the email address still needs to be confirmed.
  emailUnverified,

  /// Email confirmed, but the profile document is missing or incomplete.
  profileIncomplete,

  /// Fully signed in and ready for the home shell.
  ready,
}

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

  /// Resolves what the splash screen should show.
  ///
  /// Verification and profile checks happen before the 24-hour window, so an
  /// interrupted sign-up can never slip into the app even if Firebase still
  /// holds a session for it.
  Future<SessionStartup> startupStatus() async {
    if (!AuthService.isAvailable) return SessionStartup.signedOut;

    final user = await AuthService.instance.restoreUser();
    if (user == null) return SessionStartup.signedOut;

    if (!await AuthService.instance.isEmailVerified()) {
      return SessionStartup.emailUnverified;
    }

    final profile = await AuthService.instance.currentUserProfile();
    if (!AuthService.isProfileComplete(profile)) {
      return SessionStartup.profileIncomplete;
    }

    final prefs = await SharedPreferences.getInstance();
    var startedAt = prefs.getInt(_loginAtKey);

    if (startedAt == null) {
      final lastSignIn = user.metadata.lastSignInTime;
      if (lastSignIn == null) {
        await endSession();
        return SessionStartup.signedOut;
      }
      startedAt = lastSignIn.millisecondsSinceEpoch;
      await prefs.setInt(_loginAtKey, startedAt);
    }

    final started = DateTime.fromMillisecondsSinceEpoch(startedAt);
    if (DateTime.now().difference(started) >= sessionLength) {
      await endSession();
      return SessionStartup.signedOut;
    }
    return SessionStartup.ready;
  }

  /// Whether the current session is ready for the home shell.
  Future<bool> hasValidSession() async {
    return await startupStatus() == SessionStartup.ready;
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
