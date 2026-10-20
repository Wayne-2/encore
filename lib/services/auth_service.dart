import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'local_cache.dart';

/// Thrown when the admin ID entered on login doesn't match the one saved on
/// the account during sign-up.
class AdminIdException implements Exception {
  const AdminIdException();
}

/// Thin wrapper around Firebase Auth + Firestore for the auth screens.
///
/// The details collected across the sign-up steps stay in the screen's state
/// until authentication succeeds; [saveUserDetails] then writes them to the
/// `users/{uid}` document.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Whether Firebase is initialised in this process.
  ///
  /// Widget tests pump the auth screens without calling
  /// `Firebase.initializeApp`, so the screens fall back to their pre-Firebase
  /// behaviour when this is false.
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get currentUser => isAvailable ? _auth.currentUser : null;

  /// Resolves the user persisted from a previous launch.
  ///
  /// [currentUser] can still be null right after startup while Firebase
  /// restores the saved session, so the splash waits on the auth stream.
  Future<User?> restoreUser() async {
    if (!isAvailable) return null;
    final user = _auth.currentUser;
    if (user != null) return user;
    try {
      return await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs in with email + password.
  ///
  /// [adminId] is optional: when provided it must match the `adminId` saved on
  /// the user's document (set during sign-up). A mismatch signs the user back
  /// out and throws [AdminIdException]. Leaving it empty signs the user in as
  /// a normal (student) user.
  Future<void> signIn({
    required String email,
    required String password,
    String? adminId,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);

    final entered = adminId?.trim() ?? '';
    if (entered.isEmpty) return;

    final uid = _auth.currentUser?.uid;
    final saved = uid == null
        ? null
        : (await _firestore.collection('users').doc(uid).get())
                  .data()?['adminId']
              as String?;

    if (saved == null || saved != entered) {
      await _auth.signOut();
      throw const AdminIdException();
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String name) async {
    if (name.isEmpty) return;
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> updatePhotoUrl(String url) async {
    await _auth.currentUser?.updatePhotoURL(url);
  }

  /// Sends the verification email.
  ///
  /// Tries, in order: the Cloudflare Worker (Brevo HTTP API), the Firebase
  /// `sendVerificationEmail` Cloud Function (Admin SDK + Brevo SMTP), then
  /// Firebase's own verification email — so sign-up always gets an email.
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (await _sendVerificationViaWorker(user)) return;
    if (await _sendVerificationViaFunction(user)) return;
    await user.sendEmailVerification();
  }

  Future<bool> _sendVerificationViaWorker(User user) async {
    final base = AppConfig.r2WorkerUrl;
    if (base.isEmpty) return false;
    try {
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$base/verify/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, dynamic>{'email': user.email}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendVerificationViaFunction(User user) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendVerificationEmail')
          .call(<String, dynamic>{'email': user.email});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Stores the device's Firebase Installation ID on `users/{uid}` so push
  /// notifications can be targeted.
  Future<void> saveFcmToken(String uid, String token) {
    return _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  /// Saves a refreshed installation ID for the signed-in user, if there is
  /// one.
  Future<void> saveFcmTokenForCurrentUser(String token) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await saveFcmToken(uid, token);
  }

  /// Streams the users in a given level.
  ///
  /// Level is the grouping key for the whole app, so this is the primary way
  /// to read everyone in a cohort.
  Stream<QuerySnapshot<Map<String, dynamic>>> usersInLevel(String level) {
    return _firestore
        .collection('users')
        .where('level', isEqualTo: level)
        .snapshots();
  }

  /// Persists the details collected during sign-up to `users/{uid}`.
  Future<void> saveUserDetails({
    required String uid,
    required String fullName,
    required String username,
    required String email,
    required String registrationNumber,
    required String department,
    required String faculty,
    required String role,
    String? level,
    String? adminId,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      'fullName': fullName,
      'username': username,
      'email': email,
      'registrationNumber': registrationNumber,
      'department': department,
      'faculty': faculty,
      'role': role,
      'level': level,
      'adminId': adminId,
      'photoUrl': photoUrl,
    };

    await _firestore.collection('users').doc(uid).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    unawaited(LocalCache.instance.saveProfile(uid, data));
  }

  /// The signed-in user's profile document, or null when unavailable.
  ///
  /// Fresh Firestore data is cached in Hive, and the cache is used when the
  /// network is unavailable. Pass `fallbackToCache: false` when the caller
  /// needs to distinguish a failed refresh from cached data.
  Future<Map<String, dynamic>?> currentUserProfile({
    bool fallbackToCache = true,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return null;

    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      final data = snapshot.data();
      if (data != null) {
        unawaited(LocalCache.instance.saveProfile(uid, data));
      }
      return data;
    } catch (_) {
      if (!fallbackToCache) rethrow;
      return LocalCache.instance.profile(uid);
    }
  }

  /// The last profile saved on this device, available before the network.
  Future<Map<String, dynamic>?> cachedProfile() {
    final uid = currentUser?.uid;
    if (uid == null) return Future<Map<String, dynamic>?>.value();
    return LocalCache.instance.profile(uid);
  }

  /// Streams the signed-in user's profile document, so screens can react to
  /// edits (photo, level, department, bio) without a reload.
  ///
  /// The Hive-cached profile is emitted first so the UI can render offline.
  Stream<Map<String, dynamic>?> currentUserProfileStream() async* {
    final uid = currentUser?.uid;
    if (uid == null) {
      yield null;
      return;
    }

    final cached = await LocalCache.instance.profile(uid);
    if (cached != null) yield cached;

    try {
      await for (final snapshot
          in _firestore.collection('users').doc(uid).snapshots()) {
        final data = snapshot.data();
        if (data != null) {
          unawaited(LocalCache.instance.saveProfile(uid, data));
        }
        yield data;
      }
    } catch (_) {
      // Keep the cached profile already emitted.
    }
  }

  /// Updates the editable parts of the signed-in user's profile.
  ///
  /// Returns `false` when there is no signed-in user to update.
  Future<bool> updateProfile({
    required String username,
    required String bio,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    final updates = <String, dynamic>{
      'username': username,
      'bio': bio,
      'photoUrl': ?photoUrl,
    };
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(updates, SetOptions(merge: true));
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }

    try {
      final cached = await LocalCache.instance.profile(user.uid);
      unawaited(
        LocalCache.instance.saveProfile(user.uid, {...?cached, ...updates}),
      );
    } catch (_) {
      // The Firestore update already succeeded; a cache problem must not turn
      // it into a failed save.
    }
    return true;
  }

  /// Maps a [FirebaseAuthException] to a friendly, user-facing message.
  static String messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with that email already exists. Try logging in instead.';
      case 'invalid-email':
        return 'That email address doesn’t look right.';
      case 'weak-password':
        return 'Choose a stronger password — at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a moment.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'operation-not-allowed':
        return 'Email sign-in isn’t enabled for this project yet.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
}
