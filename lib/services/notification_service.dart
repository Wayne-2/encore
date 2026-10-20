import 'dart:async';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'auth_service.dart';

/// Android notification channel used for all Encore notifications.
const String _channelId = 'encore_default';
const String _channelName = 'Encore';
const String _channelDescription = 'General Encore notifications';
const String _icon = '@drawable/ic_notification';
const Color _accent = Color(0xFF25A10C);
const int _welcomeNotificationId = 1001;
const int _profileUpdatedNotificationId = 1002;
const int _announcementNotificationId = 1003;
const int _trendNotificationId = 1004;
const int _activityNotificationId = 1005;

/// FCM handler for messages that arrive while the app is in the background.
///
/// Runs in its own isolate, so Firebase has to be initialised again here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Centralises push (FCM) and local notifications.
///
/// On Android/iOS it asks for permission, subscribes to token refresh, shows
/// foreground messages as local notifications and stores the FCM token on the
/// user's Firestore document. Local notifications are also available on macOS.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// The Firebase Installation ID returned by `register()`, kept so the
  /// sign-up flow can persist it without waiting on the stream again.
  String? _registrationId;
  Completer<String>? _registration;

  /// Local notifications are supported on Android, iOS and macOS.
  static bool get _supportsLocal =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Push messaging is supported on Android and iOS.
  static bool get _supportsPush =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialises local notifications, requests permission and wires FCM.
  ///
  /// Safe to call more than once, and a no-op on unsupported platforms
  /// (web/Linux/Windows) — including the widget-test runner.
  Future<void> initialize() async {
    if (_initialized || !_supportsLocal) return;
    _initialized = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
            ),
          );
    }

    if (!_supportsPush) return;

    // Everything below is best-effort: a failure to set up push must never
    // take down app startup.
    try {
      // Prompts on first launch (and is idempotent afterwards).
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Let iOS present foreground pushes natively; on Android we surface them
      // ourselves as local notifications so they are styled consistently.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // `register()` + `onRegistered` replace the deprecated token APIs in
      // firebase_messaging 17; the value is the Firebase Installation ID.
      _registration = Completer<String>();
      FirebaseMessaging.instance.onRegistered.listen((id) {
        _registrationId = id;
        if (!(_registration?.isCompleted ?? true)) {
          _registration!.complete(id);
        }
        AuthService.instance.saveFcmTokenForCurrentUser(id);
      });
      await FirebaseMessaging.instance.register();
    } catch (_) {
      // e.g. the installations API is disabled or Play services is missing.
    }
  }

  /// Registers the background handler. Call once, after Firebase init.
  void registerBackgroundHandler() {
    if (!_supportsPush) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// The installation ID to store for push, or `null` when unavailable.
  Future<String?> getToken() async {
    if (!_supportsPush) return null;
    if (_registrationId != null) return _registrationId;

    final pending = _registration;
    if (pending == null) return null;
    try {
      return await pending.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return _registrationId;
    }
  }

  /// Shows the "welcome" notification after a successful sign-up.
  Future<void> showWelcome(String fullName) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final name = fullName.trim();
    await _local.show(
      id: _welcomeNotificationId,
      title: 'Welcome to Encore',
      body: name.isEmpty ? 'Your account is ready.' : 'Welcome, $name',
      notificationDetails: _details,
    );
  }

  /// Shows a confirmation after the user saves changes on the profile page.
  Future<void> showProfileUpdated() async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    await _local.show(
      id: _profileUpdatedNotificationId,
      title: 'Profile updated',
      body: 'Your profile changes have been saved.',
      notificationDetails: _details,
    );
  }

  /// Notifies the feed that [author] published an announcement with
  /// [priority] (e.g. "Highly prior").
  ///
  /// Best-effort: a platform that cannot show notifications must never break
  /// the posting flow.
  Future<void> showNewAnnouncement({
    required String author,
    required String priority,
  }) async {
    try {
      if (!_initialized) await initialize();
      if (!_initialized) return;

      final name = author.trim().isEmpty ? 'A user' : author.trim();
      await _local.show(
        id: _announcementNotificationId,
        title: 'New announcement from $name',
        body: 'Priority: $priority',
        notificationDetails: _details,
      );
    } catch (_) {
      // Local notifications are unavailable in this environment.
    }
  }

  /// Confirms that [title] was published to the Trending feed.
  ///
  /// Best-effort: posting must still succeed when notifications are blocked.
  Future<void> showTrendPosted({required String title}) async {
    try {
      if (!_initialized) await initialize();
      if (!_initialized) return;

      final name = title.trim();
      await _local.show(
        id: _trendNotificationId,
        title: 'Trend posted',
        body: name.isEmpty ? 'Your trend is now live.' : '"$name" is now live.',
        notificationDetails: _details,
      );
    } catch (_) {
      // Local notifications are unavailable in this environment.
    }
  }

  /// Confirms that [title] was added for [date] on the activities grid.
  ///
  /// Best-effort: adding an activity must still succeed when notifications
  /// are blocked.
  Future<void> showActivityAdded({
    required String title,
    required String date,
  }) async {
    try {
      if (!_initialized) await initialize();
      if (!_initialized) return;

      final name = title.trim().isEmpty ? 'Your activity' : title.trim();
      final day = date.trim();
      await _local.show(
        id: _activityNotificationId,
        title: 'Activity added',
        body: day.isEmpty
            ? '$name has been added to your activities.'
            : '$name is scheduled for $day.',
        notificationDetails: _details,
      );
    } catch (_) {
      // Local notifications are unavailable in this environment.
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // iOS/macOS present foreground pushes natively via the presentation
    // options above; Android needs an explicit local notification.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: _details,
    );
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      icon: _icon,
      color: _accent,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );
}
