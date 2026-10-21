import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/comment.dart';
import '../models/trend.dart';
import 'auth_service.dart';
import 'comment_store.dart';
import 'local_cache.dart';
import 'media_storage.dart';

/// Shared trending feed backed by Firestore's `trends` collection.
///
/// Trends and their comment threads are visible to every signed-in user. New
/// posts are inserted optimistically; their thumbnails are uploaded to R2 in
/// the background before the Firestore document is written. Without Firebase
/// (widget tests) trends stay in memory.
class TrendStore extends ChangeNotifier {
  TrendStore._();

  static final TrendStore instance = TrendStore._();

  static const String _collection = 'trends';
  static const int _maxItems = 50;

  final List<Trend> _items = [];
  final Set<String> _pendingIds = {};
  final Set<String> _deletedIds = {};
  final Map<String, int> _createdAtMillis = {};

  final Map<String, List<Comment>> _comments = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _commentSubscriptions = {};
  final Set<String> _loadedComments = {};
  final Set<String> _listeningComments = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _trendSubscription;

  List<Trend> get items => List.unmodifiable(_items);

  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection(_collection)
      .orderBy('createdAt', descending: true)
      .limit(_maxItems);

  /// Starts the live Firestore listener for the trending feed.
  /// Cached trends appear immediately while Firestore connects.
  Future<void> listen() async {
    if (!AuthService.isAvailable || _trendSubscription != null) return;

    await _loadCache();
    if (_trendSubscription != null) return;

    _trendSubscription = _query.snapshots().listen(
      _onTrends,
      onError: (Object _) {},
    );
  }

  Future<void> _loadCache() async {
    if (_items.isNotEmpty) return;

    final cached = await LocalCache.instance.trends();
    if (cached == null || cached.isEmpty || _items.isNotEmpty) return;

    _items.addAll(cached.map(_fromCachedMap));
    notifyListeners();
  }

  /// Forces a server read and refreshes the feed plus its Hive cache.
  Future<void> refresh() async {
    if (!AuthService.isAvailable) return;
    try {
      _onTrends(await _query.get());
    } catch (_) {
      // Offline: keep the cached feed.
    }
  }

  void _onTrends(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final serverDocs = snapshot.docs
        .where((doc) => !_deletedIds.contains(doc.id))
        .toList();
    final localById = {for (final trend in _items) trend.id: trend};
    final server = serverDocs.map((doc) {
      final parsed = _fromDoc(doc);
      return _mergeLocalMedia(parsed, localById[parsed.id]);
    }).toList();
    for (final doc in serverDocs) {
      _createdAtMillis[doc.id] = _timestampMillis(doc.data()['createdAt']);
    }
    final serverIds = server.map((trend) => trend.id).toSet();
    _pendingIds.removeWhere(serverIds.contains);

    // Keep optimistic posts that have not reached Firestore yet.
    final pending = _items
        .where((trend) => _pendingIds.contains(trend.id))
        .toList();

    _items
      ..clear()
      ..addAll([...pending, ...server]);
    notifyListeners();
    unawaited(_saveCache());
  }

  /// Keeps the locally uploaded thumbnail available while the remote image
  /// loads (or when the upload failed), instead of replacing the optimistic
  /// card with one that can only show a network URL.
  static Trend _mergeLocalMedia(Trend server, Trend? local) {
    if (local == null || local.media.isEmpty) return server;

    if (server.media.isEmpty) {
      return server.copyWith(media: local.media);
    }
    if (server.media.length != local.media.length) return server;

    return server.copyWith(
      media: [
        for (var i = 0; i < server.media.length; i++)
          TrendMedia(
            thumbnail: local.media[i].thumbnail,
            url: server.media[i].url,
            isVideo: server.media[i].isVideo,
            duration: server.media[i].duration,
          ),
      ],
    );
  }

  /// Publishes a trend immediately, then persists it (and its media) in the
  /// background.
  Trend post({
    required String title,
    required String body,
    required String author,
    List<TrendMedia> media = const [],
    String? authorId,
    String? photoUrl,
  }) {
    final firestore = AuthService.isAvailable
        ? FirebaseFirestore.instance
        : null;
    final doc = firestore?.collection(_collection).doc();
    final user = AuthService.isAvailable
        ? AuthService.instance.currentUser
        : null;

    final text = body.trim();
    final name = author.trim();
    final now = DateTime.now();
    final trend = Trend(
      id: doc?.id ?? 'trend-${now.microsecondsSinceEpoch}',
      authorId: authorId ?? user?.uid ?? '',
      title: title.trim(),
      subtitle: _excerpt(text),
      author: name.isEmpty ? 'You' : name,
      time: 'Just now',
      body: text,
      media: List.unmodifiable(media),
      photoUrl: photoUrl,
      createdAt: now,
    );

    _items.insert(0, trend);
    _createdAtMillis[trend.id] = now.millisecondsSinceEpoch;
    if (doc != null) {
      _pendingIds.add(trend.id);
      unawaited(_persist(doc, trend));
    }
    notifyListeners();
    unawaited(_saveCache());
    return trend;
  }

  Future<void> _persist(
    DocumentReference<Map<String, dynamic>> doc,
    Trend trend,
  ) async {
    final storage = MediaStorage(workerUrl: AppConfig.r2WorkerUrl);
    final media = <Map<String, dynamic>>[];

    try {
      for (var i = 0; i < trend.media.length; i++) {
        final item = trend.media[i];
        var url = item.url;

        if (url.isEmpty && item.thumbnail != null) {
          final type = _mediaType(item.thumbnail!);
          try {
            url = await storage.upload(
              bytes: item.thumbnail!,
              filename: '${trend.id}-$i.${type.extension}',
              contentType: type.contentType,
            );
          } catch (error) {
            debugPrint('Trend media upload failed: $error');
            continue;
          }
        }
        if (url.isEmpty) continue;

        media.add({
          'url': url,
          'isVideo': item.isVideo,
          'duration': item.duration.inMilliseconds,
        });
      }

      if (_deletedIds.contains(trend.id)) return;

      await doc.set({
        'title': trend.title,
        'subtitle': trend.subtitle,
        'author': trend.author,
        'authorId': trend.authorId,
        'photoUrl': trend.photoUrl,
        'body': trend.body,
        'media': media,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Trend write failed: $error');
      // Keep the optimistic post in memory if the write fails.
    } finally {
      storage.dispose();
    }
  }

  static ({String extension, String contentType}) _mediaType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return (extension: 'png', contentType: 'image/png');
    }
    return (extension: 'jpg', contentType: 'image/jpeg');
  }

  /// Removes [trend] from the feed and from Firestore.
  void delete(Trend trend) {
    final index = _items.indexWhere((item) => item.id == trend.id);
    if (index < 0) return;

    _items.removeAt(index);
    _pendingIds.remove(trend.id);
    _deletedIds.add(trend.id);
    _createdAtMillis.remove(trend.id);
    _comments.remove(trend.id);
    _loadedComments.remove(trend.id);
    _listeningComments.remove(trend.id);
    final subscription = _commentSubscriptions.remove(trend.id);
    if (subscription != null) unawaited(subscription.cancel());
    notifyListeners();
    unawaited(_saveCache());

    if (AuthService.isAvailable && trend.id.isNotEmpty) {
      unawaited(
        FirebaseFirestore.instance
            .collection(_collection)
            .doc(trend.id)
            .delete()
            .catchError((Object _) {}),
      );
    }
  }

  List<Comment> commentsFor(String trendId) {
    return List.unmodifiable(_comments[trendId] ?? const <Comment>[]);
  }

  bool commentsLoading(String trendId) {
    return _listeningComments.contains(trendId) &&
        !_loadedComments.contains(trendId);
  }

  /// Starts the live comment listener for [trendId]. Safe to call repeatedly.
  void listenToComments(String trendId) {
    if (trendId.isEmpty || _listeningComments.contains(trendId)) return;
    _comments.putIfAbsent(trendId, () => []);
    if (!AuthService.isAvailable || trendId.startsWith('trend-')) return;

    _listeningComments.add(trendId);
    _commentSubscriptions[trendId] = FirebaseFirestore.instance
        .collection(_collection)
        .doc(trendId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) {
            _comments[trendId] = snapshot.docs.map(commentFromDoc).toList();
            _loadedComments.add(trendId);
            notifyListeners();
          },
          onError: (Object _) {
            _loadedComments.add(trendId);
            notifyListeners();
          },
        );
  }

  void stopListeningToComments(String trendId) {
    final subscription = _commentSubscriptions.remove(trendId);
    _listeningComments.remove(trendId);
    if (subscription != null) unawaited(subscription.cancel());
  }

  /// Adds [text] to the trend's thread as the signed-in user.
  Future<void> addComment(
    String trendId,
    String text, {
    Comment? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trendId.isEmpty) return;

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

    _comments.putIfAbsent(trendId, () => []).add(local);
    notifyListeners();

    if (!AuthService.isAvailable || trendId.startsWith('trend-')) return;
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _removeLocal(trendId, local.id);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(trendId)
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
      _removeLocal(trendId, local.id);
      rethrow;
    }
  }

  /// Drops every trend and comment (used by tests).
  void clear() {
    if (_trendSubscription != null) {
      unawaited(_trendSubscription!.cancel());
      _trendSubscription = null;
    }
    for (final subscription in _commentSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _commentSubscriptions.clear();
    _listeningComments.clear();
    _loadedComments.clear();

    _items.clear();
    _pendingIds.clear();
    _deletedIds.clear();
    _createdAtMillis.clear();
    _comments.clear();
    notifyListeners();
  }

  void _removeLocal(String trendId, String commentId) {
    _comments[trendId]?.removeWhere((comment) => comment.id == commentId);
    notifyListeners();
  }

  static Trend _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Trend(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      subtitle: (data['subtitle'] as String?)?.trim() ?? '',
      author: (data['author'] as String?)?.trim() ?? 'Unknown',
      time: _formatTime(data['createdAt']),
      body: data['body'] as String? ?? '',
      media: _mediaFrom(data['media']),
      photoUrl: _cleanUrl(data['photoUrl']),
      createdAt: _dateFrom(data['createdAt']),
    );
  }

  Trend _fromCachedMap(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final createdAt = data['createdAt'];
    if (createdAt is int) _createdAtMillis[id] = createdAt;
    return Trend(
      id: id,
      authorId: data['authorId'] as String? ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      subtitle: (data['subtitle'] as String?)?.trim() ?? '',
      author: (data['author'] as String?)?.trim() ?? 'Unknown',
      time: createdAt == null
          ? (data['time'] as String? ?? 'Just now')
          : _formatTime(createdAt),
      body: data['body'] as String? ?? '',
      media: _mediaFrom(data['media']),
      photoUrl: _cleanUrl(data['photoUrl']),
      createdAt: _dateFrom(createdAt),
    );
  }

  Future<void> _saveCache() {
    return LocalCache.instance.saveTrends([
      for (final trend in _items) _toCache(trend),
    ]);
  }

  Map<String, dynamic> _toCache(Trend trend) {
    final createdAt = _createdAtMillis[trend.id];
    return {
      'id': trend.id,
      'authorId': trend.authorId,
      'title': trend.title,
      'subtitle': trend.subtitle,
      'author': trend.author,
      'time': trend.time,
      'photoUrl': trend.photoUrl,
      'body': trend.body,
      'createdAt': createdAt,
      'media': [
        for (final item in trend.media)
          {
            'url': item.url,
            'isVideo': item.isVideo,
            'duration': item.duration.inMilliseconds,
          },
      ],
    };
  }

  static int _timestampMillis(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.millisecondsSinceEpoch,
      DateTime time => time.millisecondsSinceEpoch,
      int millis => millis,
      _ => DateTime.now().millisecondsSinceEpoch,
    };
  }

  static DateTime? _dateFrom(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime time => time,
      int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      _ => null,
    };
  }

  static String? _cleanUrl(Object? value) {
    final url = value is String ? value.trim() : '';
    return url.isEmpty ? null : url;
  }

  static List<TrendMedia> _mediaFrom(Object? value) {
    if (value is! List) return const [];

    final media = <TrendMedia>[];
    for (final item in value) {
      if (item is! Map) continue;
      final url = (item['url'] as String?)?.trim() ?? '';
      if (url.isEmpty) continue;
      final duration = item['duration'];
      media.add(
        TrendMedia(
          url: url,
          isVideo: item['isVideo'] == true,
          duration: Duration(
            milliseconds: duration is num ? duration.toInt() : 0,
          ),
        ),
      );
    }
    return media;
  }

  static String _formatTime(Object? value) {
    final relative = CommentStore.formatTimestamp(value);
    return relative == 'now' ? 'Just now' : relative;
  }

  static String _excerpt(String body) {
    final firstLine = body.split('\n').first.trim();
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.substring(0, 60).trimRight()}…';
  }
}
