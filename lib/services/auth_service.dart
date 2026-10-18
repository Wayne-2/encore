import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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

  Future<void> signUp({required String email, required String password}) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String name) async {
    if (name.isEmpty) return;
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> updatePhotoUrl(String url) async {
    await _auth.currentUser?.updatePhotoURL(url);
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Stores the device's FCM token on `users/{uid}` so push can be targeted.
  Future<void> saveFcmToken(String uid, String token) {
    return _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  /// Saves a refreshed FCM token for the signed-in user, if there is one.
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
  }) {
    return _firestore.collection('users').doc(uid).set({
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
      'createdAt': FieldValue.serverTimestamp(),
    });
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
