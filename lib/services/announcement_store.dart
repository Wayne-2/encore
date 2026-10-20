import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../data/departments.dart';
import '../models/announcement.dart';
import '../theme/spotify_colors.dart';
import 'auth_service.dart';

/// Shared announcement feed backed by Firestore's `announcements` collection.
///
/// Announcements are scoped to the signed-in user's department and level, so a
/// post is only visible to the group it was written for. The store keeps posts
/// in memory when Firebase is unavailable (tests) and marks announcements that
/// arrive while the app is open as unread until they are opened.
class AnnouncementStore extends ChangeNotifier {
  AnnouncementStore._();

  static final AnnouncementStore instance = AnnouncementStore._();

  static const String _collection = 'announcements';
  static const int _maxItems = 50;

  final List<Announcement> _items = [];
  final Set<String> _unreadIds = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _hasLoaded = false;
  bool _starting = false;
  String _department = '';
  String _level = '';
  int _nextId = 0;

  List<Announcement> get items => List.unmodifiable(_items);

  /// Starts the live Firestore listener for the signed-in user's group.
  /// Safe to call more than once.
  Future<void> listen() async {
    if (Firebase.apps.isEmpty || _subscription != null || _starting) return;
    _starting = true;

    try {
      final profile = await AuthService.instance.currentUserProfile();
      final department = normalizeDepartment(
        (profile?['department'] as String?) ?? '',
      );
      final level = (profile?['level'] as String?)?.trim() ?? '';
      if (department.isEmpty || level.isEmpty) {
        _starting = false;
        return;
      }

      _department = department;
      _level = level;
      _subscription = FirebaseFirestore.instance
          .collection(_collection)
          .where('department', isEqualTo: department)
          .where('level', isEqualTo: level)
          .orderBy('createdAt', descending: true)
          .limit(_maxItems)
          .snapshots()
          .listen(_onSnapshot, onError: (Object _) {});
    } catch (_) {
      _starting = false;
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    // Announcements that appear after the first snapshot are new arrivals, so
    // they stay unread until the user opens them. The initial batch is treated
    // as already read.
    if (_hasLoaded) {
      final existingIds = _items.map((item) => item.id).toSet();
      for (final doc in snapshot.docs) {
        if (!existingIds.contains(doc.id)) _unreadIds.add(doc.id);
      }
    }

    _items
      ..clear()
      ..addAll(snapshot.docs.map(_fromDoc));
    _hasLoaded = true;
    notifyListeners();
  }

  /// Publishes a new announcement for the signed-in user's department and
  /// level, and writes it to Firestore.
  Announcement post({
    required String author,
    required String authorId,
    required String tag,
    required Color tagColor,
    required String body,
    String? photoUrl,
    String? department,
    String? level,
  }) {
    final firestore = Firebase.apps.isEmpty ? null : FirebaseFirestore.instance;
    final doc = firestore?.collection(_collection).doc();
    final groupDepartment = normalizeDepartment(department ?? _department);
    final groupLevel = (level ?? _level).trim();

    final announcement = Announcement(
      id:
          doc?.id ??
          'ann-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
      author: author,
      authorId: authorId,
      photoUrl: photoUrl,
      time: _clockNow(),
      tag: tag,
      tagColor: tagColor,
      body: body,
      unread: true,
    );

    // Show the post immediately; the live snapshot reconciles it shortly.
    _items.insert(0, announcement);
    _unreadIds.add(announcement.id);
    notifyListeners();

    if (doc != null) {
      unawaited(
        doc
            .set({
              'author': author,
              'authorId': authorId,
              'photoUrl': photoUrl,
              'department': groupDepartment,
              'level': groupLevel,
              'tag': tag,
              'tagColor': tagColor.toARGB32(),
              'body': body,
              'createdAt': FieldValue.serverTimestamp(),
            })
            .catchError((Object _) {
              // Keep the optimistic post; a later snapshot will reconcile it.
            }),
      );
    }

    return announcement;
  }

  /// Clears the unread dot for [announcement] (when its tile is opened).
  void markRead(Announcement announcement) {
    if (!_unreadIds.remove(announcement.id)) return;
    final index = _items.indexWhere((item) => item.id == announcement.id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(unread: false);
    }
    notifyListeners();
  }

  /// Removes [announcement] from the feed and from Firestore.
  void delete(Announcement announcement) {
    final index = _items.indexWhere((item) => item.id == announcement.id);
    if (index < 0) return;

    _items.removeAt(index);
    _unreadIds.remove(announcement.id);
    notifyListeners();

    if (Firebase.apps.isNotEmpty && announcement.id.isNotEmpty) {
      unawaited(
        FirebaseFirestore.instance
            .collection(_collection)
            .doc(announcement.id)
            .delete()
            .catchError((Object _) {}),
      );
    }
  }

  /// Drops every announcement from memory (the live listener repopulates it).
  void clear() {
    if (_items.isEmpty && _unreadIds.isEmpty) return;
    _items.clear();
    _unreadIds.clear();
    notifyListeners();
  }

  Announcement _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Announcement(
      id: doc.id,
      author: (data['author'] as String?)?.trim() ?? 'Unknown',
      authorId: data['authorId'] as String? ?? '',
      photoUrl: (data['photoUrl'] as String?)?.trim(),
      time: _formatTimestamp(data['createdAt']),
      tag: data['tag'] as String? ?? 'General announcement',
      tagColor: _tagColorFrom(data['tagColor']),
      body: data['body'] as String? ?? '',
      unread: _unreadIds.contains(doc.id),
    );
  }

  static Color _tagColorFrom(Object? value) {
    if (value is num) return Color(value.toInt());
    return SpotifyColors.tagInfo;
  }

  static String _formatTimestamp(Object? value) {
    final DateTime? date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime time => time,
      _ => null,
    };
    if (date == null) return _clockNow();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;

    if (difference <= 0) return _clock(date);
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return _weekdays[date.weekday - 1];
    return '${_months[date.month - 1]} ${date.day}';
  }

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

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

  static String _clockNow() => _clock(DateTime.now());

  static String _clock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
