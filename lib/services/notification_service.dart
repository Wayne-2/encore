import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
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

const String _todoChannelId = 'encore_todos';
const String _todoChannelName = 'Todo reminders';
const String _todoChannelDescription = 'Alarms for your personal todo list';

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
  bool _chatNotificationsHandledInApp = false;
  bool _askedForExactAlarms = false;

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
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _todoChannelId,
          _todoChannelName,
          description: _todoChannelDescription,
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
        unawaited(
          AuthService.instance
              .saveFcmTokenForCurrentUser(id)
              .catchError((_) {}),
        );
      });

      // The installation ID is often ready before anyone signs in, so listen
      // for auth changes and attach it once a user is available.
      if (AuthService.isAvailable) {
        FirebaseAuth.instance.authStateChanges().listen((user) {
          final id = _registrationId;
          if (user != null && id != null) {
            unawaited(
              AuthService.instance
                  .saveFcmTokenForCurrentUser(id)
                  .catchError((_) {}),
            );
          }
        });
      }

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

  /// Queues a push for a newly created contact request and tries it now.
  ///
  /// The outbox document is durable, so the Worker cron retries it if this
  /// device is offline or the immediate request fails.
  Future<void> notifyContactRequest(String requestId) async {
    final outboxId = await _enqueueOutbox(
      type: 'contact_request',
      requestId: requestId,
    );
    if (outboxId != null) unawaited(_dispatchOutbox(outboxId));
  }

  /// Queues a push for a newly sent message and tries it now.
  ///
  /// Best-effort: notification delivery must never break sending a message.
  Future<void> notifyMessage({
    required String chatId,
    required String messageId,
  }) async {
    final outboxId = await _enqueueOutbox(
      type: 'chat_message',
      chatId: chatId,
      messageId: messageId,
    );
    if (outboxId != null) unawaited(_dispatchOutbox(outboxId));
  }

  /// Writes a pending notification job to Firestore.
  Future<String?> _enqueueOutbox({
    required String type,
    String? requestId,
    String? chatId,
    String? messageId,
  }) async {
    if (!AuthService.isAvailable) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final ref = FirebaseFirestore.instance
        .collection('notificationOutbox')
        .doc();
    try {
      await ref.set({
        'type': type,
        'actorId': user.uid,
        'status': 'pending',
        'attempts': 0,
        'requestId': ?requestId,
        'chatId': ?chatId,
        'messageId': ?messageId,
        'createdAt': FieldValue.serverTimestamp(),
        'nextAttemptAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (_) {
      // The message/request itself has already been written; never fail it
      // because the notification outbox is unavailable.
      return null;
    }
  }

  /// Nudges the Worker to process [outboxId] immediately.
  ///
  /// If this fails, the outbox document stays pending and the Worker cron
  /// retries it with backoff.
  Future<void> _dispatchOutbox(String outboxId) async {
    if (!AuthService.isAvailable) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final base = AppConfig.r2WorkerUrl.trim();
    if (base.isEmpty) return;

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return;
      await http
          .post(
            Uri.parse('$base/notify/outbox'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'outboxId': outboxId}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // The outbox remains queued for the scheduled retry.
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

  /// Schedules a local alarm for [todoId] at [at].
  ///
  /// Exact alarms are used when the OS grants the permission; otherwise the
  /// notification falls back to an inexact idle-safe alarm. Best-effort: a
  /// platform that cannot schedule notifications must never break saving.
  Future<void> scheduleTodo({
    required String todoId,
    required String title,
    required DateTime at,
    String note = '',
    int badgeCount = 1,
  }) async {
    try {
      if (!at.isAfter(DateTime.now())) return;
      if (!_initialized) await initialize();
      if (!_initialized) return;

      tz.initializeTimeZones();
      final id = _todoNotificationId(todoId);
      await _local.cancel(id: id);

      var exact = false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        exact = await android?.canScheduleExactNotifications() ?? false;
        if (!exact && !_askedForExactAlarms) {
          _askedForExactAlarms = true;
          await android?.requestExactAlarmsPermission();
          exact = await android?.canScheduleExactNotifications() ?? false;
        }
      }

      final trimmedNote = note.trim();
      await _local.zonedSchedule(
        id: id,
        title: 'Todo alarm',
        body: trimmedNote.isEmpty ? title : '$title — $trimmedNote',
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: _todoDetails(badgeCount),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'type': 'todo', 'todoId': todoId}),
      );
    } catch (_) {
      // Scheduled notifications are unavailable in this environment.
    }
  }

  /// Cancels the alarm previously scheduled for [todoId].
  Future<void> cancelTodo(String todoId) async {
    try {
      if (!_initialized) return;
      await _local.cancel(id: _todoNotificationId(todoId));
    } catch (_) {
      // Cancelling an alarm is best-effort.
    }
  }

  /// Stable, collision-resistant notification id for a todo.
  static int _todoNotificationId(String todoId) {
    var hash = 0x811c9dc5;
    for (final unit in todoId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 10000 + (hash % 100000000);
  }

  /// Tells the foreground FCM handler whether the signed-in app shell is
  /// already watching chats and posting message notifications itself.
  ///
  /// While enabled, foreground chat pushes are skipped on Android so the same
  /// message is not announced twice.
  void handleChatNotificationsInApp(bool enabled) {
    _chatNotificationsHandledInApp = enabled;
  }

  /// Shows an incoming chat message immediately from the in-app chat watcher.
  ///
  /// Uses the chat id as the Android tag (and iOS thread id), matching the
  /// notification sent by the Worker so a later FCM delivery replaces this
  /// one instead of appearing beside it.
  Future<void> showIncomingMessage({
    required String chatId,
    required String title,
    required String body,
  }) async {
    try {
      if (!_initialized) await initialize();
      if (!_initialized) return;

      final android = defaultTargetPlatform == TargetPlatform.android;
      await _local.show(
        id: android ? 0 : chatId.hashCode,
        title: title,
        body: body,
        notificationDetails: _messageDetails(chatId),
        payload: jsonEncode({'type': 'chat_message', 'chatId': chatId}),
      );
    } catch (_) {
      // Local notifications are unavailable in this environment.
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // iOS/macOS present foreground pushes natively via the presentation
    // options above; Android needs an explicit local notification.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_chatNotificationsHandledInApp &&
        message.data['type'] == 'chat_message') {
      // Already posted by the in-app watcher, usually well before FCM lands.
      return;
    }
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: _details,
    );
  }

  static NotificationDetails _messageDetails(String chatId) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: _icon,
        color: _accent,
        importance: Importance.max,
        priority: Priority.high,
        tag: chatId,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: chatId),
      macOS: DarwinNotificationDetails(threadIdentifier: chatId),
    );
  }

  static NotificationDetails _todoDetails(int badgeCount) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _todoChannelId,
        _todoChannelName,
        channelDescription: _todoChannelDescription,
        icon: _icon,
        color: _accent,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        number: badgeCount,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        badgeNumber: badgeCount,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        badgeNumber: badgeCount,
      ),
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
