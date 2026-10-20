import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../data/departments.dart';
import '../models/announcement.dart';
import '../theme/spotify_colors.dart';
import 'auth_service.dart';
import 'local_cache.dart';

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
  final Set<String> _deletedIds = {};
  final Map<String, int> _createdAtMillis = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _hasLoaded = false;
  bool _starting = false;
  String _department = '';
  String _level = '';
  int _nextId = 0;

  List<Announcement> get items => List.unmodifiable(_items);

  /// Starts the live Firestore listener for the signed-in user's group.
  /// Cached posts appear immediately, then Firestore reconciles them.
  Future<void> listen() async {
    if (Firebase.apps.isEmpty || _subscription != null || _starting) return;
    _starting = true;

    try {
      if (!await _ensureGroup()) return;
      await _loadCache();
      if (_subscription != null) return;

      _subscription = _query.snapshots().listen(
        _onSnapshot,
        onError: (Object _) {},
      );
    } catch (_) {
      // Keep any cached posts available when the network is unavailable.
    } finally {
      _starting = false;
    }
  }

  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection(_collection)
      .where('department', isEqualTo: _department)
      .where('level', isEqualTo: _level)
      .orderBy('createdAt', descending: true)
      .limit(_maxItems);

  Future<bool> _ensureGroup() async {
    if (_department.isNotEmpty && _level.isNotEmpty) return true;

    final profile = await AuthService.instance.currentUserProfile();
    final department = normalizeDepartment(
      (profile?['department'] as String?) ?? '',
    );
    final level = (profile?['level'] as String?)?.trim() ?? '';
    if (department.isEmpty || level.isEmpty) return false;

    _department = department;
    _level = level;
    return true;
  }

  Future<void> _loadCache() async {
    if (_items.isNotEmpty || _hasLoaded) return;

    final cached = await LocalCache.instance.announcements(_department, _level);
    if (cached == null || cached.isEmpty || _items.isNotEmpty) return;

    _items.addAll(cached.map(_fromCachedMap));
    _hasLoaded = true;
    notifyListeners();
  }

  /// Forces a server read and refreshes the feed plus its Hive cache.
  Future<void> refresh() async {
    if (Firebase.apps.isEmpty) return;
    try {
      if (!await _ensureGroup()) return;
      _onSnapshot(await _query.get());
    } catch (_) {
      // Offline: keep the cached feed.
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    // Ignore docs whose optimistic deletion has not reached the server yet.
    final docs = snapshot.docs
        .where((doc) => !_deletedIds.contains(doc.id))
        .toList();

    // Announcements that appear after the first snapshot are new arrivals, so
    // they stay unread until the user opens them. The initial batch is treated
    // as already read.
    if (_hasLoaded) {
      final existingIds = _items.map((item) => item.id).toSet();
      for (final doc in docs) {
        if (!existingIds.contains(doc.id)) _unreadIds.add(doc.id);
      }
    }

    _items
      ..clear()
      ..addAll(docs.map(_fromDoc));
    for (final doc in docs) {
      _createdAtMillis[doc.id] = _timestampMillis(doc.data()['createdAt']);
    }
    _hasLoaded = true;
    notifyListeners();
    unawaited(_saveCache());
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
    _createdAtMillis[announcement.id] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    unawaited(_saveCache());

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
    _deletedIds.add(announcement.id);
    _createdAtMillis.remove(announcement.id);
    notifyListeners();
    unawaited(_saveCache());

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
    if (_items.isEmpty && _unreadIds.isEmpty && _deletedIds.isEmpty) return;
    _items.clear();
    _unreadIds.clear();
    _deletedIds.clear();
    _createdAtMillis.clear();
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

  Announcement _fromCachedMap(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final createdAt = _timestampMillis(data['createdAt']);
    _createdAtMillis[id] = createdAt;
    return Announcement(
      id: id,
      author: (data['author'] as String?)?.trim() ?? 'Unknown',
      authorId: data['authorId'] as String? ?? '',
      photoUrl: (data['photoUrl'] as String?)?.trim(),
      time: _formatTimestamp(data['createdAt']),
      tag: data['tag'] as String? ?? 'General announcement',
      tagColor: _tagColorFrom(data['tagColor']),
      body: data['body'] as String? ?? '',
      unread: _unreadIds.contains(id),
    );
  }

  Future<void> _saveCache() {
    if (_department.isEmpty || _level.isEmpty) {
      return Future<void>.value();
    }

    return LocalCache.instance.saveAnnouncements(_department, _level, [
      for (final item in _items)
        {
          'id': item.id,
          'author': item.author,
          'authorId': item.authorId,
          'photoUrl': item.photoUrl,
          'tag': item.tag,
          'tagColor': item.tagColor.toARGB32(),
          'body': item.body,
          'createdAt':
              _createdAtMillis[item.id] ??
              DateTime.now().millisecondsSinceEpoch,
        },
    ]);
  }

  static int _timestampMillis(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.millisecondsSinceEpoch,
      DateTime time => time.millisecondsSinceEpoch,
      int millis => millis,
      _ => DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Color _tagColorFrom(Object? value) {
    if (value is num) return Color(value.toInt());
    return SpotifyColors.tagInfo;
  }

  static String _formatTimestamp(Object? value) {
    final DateTime? date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime time => time,
      int millis => DateTime.fromMillisecondsSinceEpoch(millis),
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
