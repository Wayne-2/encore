import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../utils/content_lifetime.dart';
import 'auth_service.dart';
import 'local_cache.dart';

/// Shared upcoming activities backed by Firestore's `activities` collection.
///
/// Activities added by users are persisted for everyone. Items are ordered
/// upcoming-first, with past activities (greyed out) at the end.
class ActivityStore extends ChangeNotifier {
  ActivityStore._();

  static final ActivityStore instance = ActivityStore._();

  static const String _collection = 'activities';
  static const int _maxItems = 100;

  final List<Activity> _items = [];
  final Set<String> _pendingIds = {};
  final Set<String> _deletedIds = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// Upcoming activities sorted by date, followed by past activities.
  /// Activities older than [ContentLifetime.activity] are excluded.
  List<Activity> get items {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final all = _items.where((activity) => !activity.isExpired()).toList();

    final upcoming =
        all.where((activity) => !activity.date.isBefore(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final past = all.where((activity) => activity.date.isBefore(today)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return List.unmodifiable([...upcoming, ...past]);
  }

  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection(_collection)
      .orderBy('date')
      .limit(_maxItems);

  /// Starts the live Firestore listener for activities.
  /// Cached activities appear immediately while Firestore connects.
  Future<void> listen() async {
    if (!AuthService.isAvailable || _subscription != null) return;

    await _loadCache();
    if (_subscription != null) return;

    _subscription = _query.snapshots().listen(
      _onSnapshot,
      onError: (Object _) {},
    );
  }

  Future<void> _loadCache() async {
    if (_items.isNotEmpty) return;

    final cached = await LocalCache.instance.activities();
    if (cached == null || cached.isEmpty || _items.isNotEmpty) return;

    _items.addAll(cached.map(_fromCachedMap));
    _dropExpired();
    notifyListeners();
    unawaited(_saveCache());
  }

  /// Forces a server read and refreshes the grid plus its Hive cache.
  Future<void> refresh() async {
    if (!AuthService.isAvailable) return;
    try {
      _onSnapshot(await _query.get());
    } catch (_) {
      // Offline: keep the cached activities.
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final parsed = snapshot.docs
        .where((doc) => !_deletedIds.contains(doc.id))
        .map(_fromDoc)
        .toList();
    final expired = parsed.where((activity) => activity.isExpired()).toList();
    _purgeRemote(expired);
    final server = parsed.where((activity) => !activity.isExpired()).toList();
    final serverIds = server.map((activity) => activity.id).toSet();
    _pendingIds.removeWhere(serverIds.contains);

    final pending = _items
        .where((activity) => _pendingIds.contains(activity.id))
        .toList();

    _items
      ..clear()
      ..addAll([...pending, ...server]);
    notifyListeners();
    unawaited(_saveCache());
  }

  /// Publishes an activity locally and writes it to Firestore.
  Activity add({
    required String title,
    required DateTime date,
    String? authorId,
    DateTime? createdAt,
  }) {
    final text = title.trim();
    final day = DateTime(date.year, date.month, date.day);
    final firestore = AuthService.isAvailable
        ? FirebaseFirestore.instance
        : null;
    final doc = firestore?.collection(_collection).doc();
    final user = AuthService.isAvailable
        ? AuthService.instance.currentUser
        : null;

    final activity = Activity(
      id: doc?.id ?? 'activity-${DateTime.now().microsecondsSinceEpoch}',
      authorId: authorId ?? user?.uid ?? '',
      title: text,
      date: day,
      createdAt: createdAt ?? DateTime.now(),
    );

    _items.add(activity);
    notifyListeners();
    unawaited(_saveCache());

    if (doc != null) {
      _pendingIds.add(activity.id);
      unawaited(
        doc
            .set({
              'title': text,
              'date': Timestamp.fromDate(day),
              'authorId': activity.authorId,
              'createdAt': FieldValue.serverTimestamp(),
            })
            .catchError((Object _) {
              // Keep the optimistic activity; a later snapshot reconciles it.
            }),
      );
    }

    return activity;
  }

  /// Removes [activity] from the grid and from Firestore.
  void delete(Activity activity) {
    final index = _items.indexWhere((item) => item.id == activity.id);
    if (index < 0) return;

    _items.removeAt(index);
    _pendingIds.remove(activity.id);
    _deletedIds.add(activity.id);
    notifyListeners();
    unawaited(_saveCache());

    if (AuthService.isAvailable && activity.id.isNotEmpty) {
      unawaited(
        FirebaseFirestore.instance
            .collection(_collection)
            .doc(activity.id)
            .delete()
            .catchError((Object _) {}),
      );
    }
  }

  /// Removes expired activities from memory, cache and (for the author)
  /// Firestore. Safe to call repeatedly.
  void pruneExpired() {
    if (!_dropExpired()) return;
    notifyListeners();
    unawaited(_saveCache());
  }

  bool _dropExpired() {
    final expired = _items.where((activity) => activity.isExpired()).toList();
    if (expired.isEmpty) return false;
    for (final activity in expired) {
      _items.remove(activity);
      _pendingIds.remove(activity.id);
      _deletedIds.add(activity.id);
    }
    _purgeRemote(expired);
    return true;
  }

  void _purgeRemote(List<Activity> expired) {
    if (expired.isEmpty || !AuthService.isAvailable) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    var queued = false;
    for (final activity in expired) {
      if (activity.id.isEmpty || activity.authorId != uid) continue;
      batch.delete(
        FirebaseFirestore.instance.collection(_collection).doc(activity.id),
      );
      queued = true;
    }
    if (queued) {
      unawaited(batch.commit().catchError((Object _) {}));
    }
  }

  /// Drops the activities and stops listening (used by tests).
  void clear() {
    if (_subscription != null) {
      unawaited(_subscription!.cancel());
      _subscription = null;
    }
    _items.clear();
    _pendingIds.clear();
    _deletedIds.clear();
    notifyListeners();
  }

  static Activity _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final value = data['date'];
    final date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime time => time,
      int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      _ => DateTime.now(),
    };

    return Activity(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      date: DateTime(date.year, date.month, date.day),
      createdAt: _dateFrom(data['createdAt']),
    );
  }

  static Activity _fromCachedMap(Map<String, dynamic> data) {
    final value = data['date'];
    final date = switch (value) {
      int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      String text => DateTime.tryParse(text) ?? DateTime.now(),
      _ => DateTime.now(),
    };

    return Activity(
      id: data['id'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      date: DateTime(date.year, date.month, date.day),
      createdAt: data['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : null,
    );
  }

  static DateTime? _dateFrom(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime time => time,
      int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      _ => null,
    };
  }

  Future<void> _saveCache() {
    return LocalCache.instance.saveActivities([
      for (final activity in _items) _toCache(activity),
    ]);
  }

  static Map<String, dynamic> _toCache(Activity activity) {
    return {
      'id': activity.id,
      'authorId': activity.authorId,
      'title': activity.title,
      'date': activity.date.millisecondsSinceEpoch,
      if (activity.createdAt != null)
        'createdAt': activity.createdAt!.millisecondsSinceEpoch,
    };
  }
}
