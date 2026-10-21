import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/comment.dart';
import 'auth_service.dart';

/// Maps a Firestore comment document to the shared UI model.
Comment commentFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final name = (data['author'] as String?)?.trim() ?? 'Unknown';
  final storedInitials = (data['initials'] as String?)?.trim();
  final photoUrl = (data['photoUrl'] as String?)?.trim();

  return Comment(
    id: doc.id,
    authorId: data['authorId'] as String? ?? '',
    name: name,
    handle: data['handle'] as String? ?? '',
    time: CommentStore.formatTimestamp(data['createdAt']),
    text: data['text'] as String? ?? '',
    initials: storedInitials != null && storedInitials.isNotEmpty
        ? storedInitials
        : CommentAuthor.initialsFor(name),
    photoUrl: photoUrl == null || photoUrl.isEmpty ? null : photoUrl,
    createdAt: _dateFrom(data['createdAt']),
    replyToId: data['replyToId'] as String? ?? '',
    replyToName: data['replyToName'] as String? ?? '',
    replyToText: data['replyToText'] as String? ?? '',
  );
}

DateTime? _dateFrom(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime time => time,
    int millis => DateTime.fromMillisecondsSinceEpoch(millis),
    _ => null,
  };
}

/// The signed-in user's display details for a new comment.
class CommentAuthor {
  const CommentAuthor({
    required this.id,
    required this.name,
    required this.handle,
    required this.initials,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String handle;
  final String initials;
  final String? photoUrl;

  /// Resolves the current profile, with a stable fallback for offline use and
  /// widget tests.
  static Future<CommentAuthor> current() async {
    if (!AuthService.isAvailable) {
      return const CommentAuthor(
        id: '',
        name: 'You',
        handle: '@you',
        initials: 'Y',
      );
    }

    final user = AuthService.instance.currentUser;
    Map<String, dynamic>? profile;
    try {
      profile = await AuthService.instance.currentUserProfile();
    } catch (_) {
      // Fall back to the Firebase Auth display name.
    }

    final storedName = (profile?['fullName'] as String?)?.trim();
    final displayName = user?.displayName?.trim();
    final name = storedName != null && storedName.isNotEmpty
        ? storedName
        : (displayName != null && displayName.isNotEmpty ? displayName : 'You');

    final username = (profile?['username'] as String?)?.trim();
    final handle = username == null || username.isEmpty
        ? '@you'
        : (username.startsWith('@') ? username : '@$username');
    final photoUrl = (profile?['photoUrl'] as String?)?.trim();

    return CommentAuthor(
      id: user?.uid ?? '',
      name: name,
      handle: handle,
      initials: initialsFor(name),
      photoUrl: photoUrl == null || photoUrl.isEmpty ? null : photoUrl,
    );
  }

  /// First letters of the first two words, e.g. `Odeh Solomon` -> `OS`.
  static String initialsFor(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}

/// Live comment threads for announcements.
///
/// Comments live at `announcements/{id}/comments`, so they are scoped to the
/// same department/level as the announcement. Without Firebase (widget tests)
/// comments are kept in memory so the UI still works.
class CommentStore extends ChangeNotifier {
  CommentStore._();

  static final CommentStore instance = CommentStore._();

  final Map<String, List<Comment>> _comments = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = {};
  final Set<String> _loaded = {};
  final Set<String> _listening = {};

  List<Comment> commentsFor(String announcementId) {
    return List.unmodifiable(_comments[announcementId] ?? const <Comment>[]);
  }

  bool isLoading(String announcementId) {
    return _listening.contains(announcementId) &&
        !_loaded.contains(announcementId);
  }

  /// Starts loading the announcement's comments. Safe to call repeatedly.
  void listen(String announcementId) {
    if (announcementId.isEmpty || _listening.contains(announcementId)) return;

    _comments.putIfAbsent(announcementId, () => []);
    // Announcements without a real document id (e.g. previews in tests) keep
    // their comments in memory only.
    if (announcementId.startsWith('local-') || !AuthService.isAvailable) return;

    _listening.add(announcementId);
    _subscriptions[announcementId] = FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcementId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) {
            _comments[announcementId] = snapshot.docs.map(_fromDoc).toList();
            _loaded.add(announcementId);
            notifyListeners();
          },
          onError: (Object _) {
            _loaded.add(announcementId);
            notifyListeners();
          },
        );
  }

  /// Stops the live listener for [announcementId] (the cache is kept).
  void stopListening(String announcementId) {
    final subscription = _subscriptions.remove(announcementId);
    _listening.remove(announcementId);
    unawaited(subscription?.cancel());
  }

  /// Posts [text] as the signed-in user, with an optimistic local entry.
  Future<void> add(
    String announcementId,
    String text, {
    Comment? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || announcementId.isEmpty) return;

    final author = await CommentAuthor.current();
    final now = DateTime.now();
    final local = Comment(
      id: 'local-${now.microsecondsSinceEpoch}',
      authorId: author.id,
      name: author.name,
      handle: author.handle,
      time: 'Just now',
      text: trimmed,
      initials: author.initials,
      photoUrl: author.photoUrl,
      createdAt: now,
      replyToId: replyTo?.id ?? '',
      replyToName: replyTo?.name ?? '',
      replyToText: replyTo?.text ?? '',
    );

    _comments.putIfAbsent(announcementId, () => []).add(local);
    notifyListeners();

    if (announcementId.startsWith('local-') || !AuthService.isAvailable) return;
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _removeLocal(announcementId, local.id);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcementId)
          .collection('comments')
          .add({
            'authorId': user.uid,
            'author': author.name,
            'handle': author.handle,
            'initials': author.initials,
            'photoUrl': author.photoUrl,
            'text': trimmed,
            'createdAt': FieldValue.serverTimestamp(),
            if (replyTo != null) ...{
              'replyToId': replyTo.id,
              'replyToName': replyTo.name,
              'replyToText': replyTo.text,
            },
          });
    } catch (_) {
      _removeLocal(announcementId, local.id);
      rethrow;
    }
  }

  /// Clears all threads and listeners (used by tests).
  void clear() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _comments.clear();
    _loaded.clear();
    _listening.clear();
    notifyListeners();
  }

  void _removeLocal(String announcementId, String commentId) {
    _comments[announcementId]?.removeWhere(
      (comment) => comment.id == commentId,
    );
    notifyListeners();
  }

  static Comment _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return commentFromDoc(doc);
  }

  /// Relative time for a Firestore timestamp (`now`, `4m`, `2h`, `3d`).
  static String formatTimestamp(Object? value) {
    final DateTime? date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime time => time,
      int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      _ => null,
    };
    if (date == null) return 'now';

    final difference = DateTime.now().difference(date);
    if (difference.inSeconds < 60) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${_months[date.month - 1]} ${date.day}';
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
