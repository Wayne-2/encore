import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/departments.dart';
import '../models/chat_conversation.dart';
import '../models/story.dart';
import 'auth_service.dart';
import 'chat_media_cache.dart';
import 'local_cache.dart';
import 'media_storage.dart';

/// Live stories for the signed-in user's department + level.
///
/// Posts are stored in the `stories` collection with a 24-hour lifetime. The
/// store also keeps the latest feed in Hive so the reel survives a cold launch
/// before Firestore responds. Without Firebase (widget tests/offline demo) the
/// original design stories are used instead.
class StoryStore extends ChangeNotifier {
  StoryStore._();

  static final StoryStore instance = StoryStore._();

  static const String _collection = 'stories';
  static const int _maxItems = 60;
  static const Duration _lifetime = Duration(hours: 24);

  final List<StoryItem> _items = [];
  final Set<String> _seenIds = {};
  final Set<String> _deletedIds = {};
  final Map<String, int> _createdAtMillis = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _hasLoaded = false;
  bool _starting = false;
  String _department = '';
  String _level = '';
  String? _viewerId;

  bool get isEnabled =>
      Firebase.apps.isNotEmpty && AuthService.instance.currentUser != null;

  /// Audience label shown in the composer, e.g. `CSC 200`.
  String get groupLabel {
    if (_department.isEmpty || _level.isEmpty) return 'My Story';
    return '$_department $_level';
  }

  String? get viewerId =>
      _viewerId ?? (isEnabled ? AuthService.instance.currentUser?.uid : null);

  /// The active stories, newest first.
  List<StoryItem> get items {
    if (Firebase.apps.isEmpty) {
      return [
        for (final story in MockChatData.stories)
          story.copyWith(
            hasUnread: !_seenIds.contains(story.id) && !story.isMine(viewerId),
            viewers: story.viewers,
          ),
      ];
    }
    final cutoff = DateTime.now().subtract(_lifetime);
    final active =
        _items
            .where(
              (story) =>
                  story.createdAt == null || story.createdAt!.isAfter(cutoff),
            )
            .toList()
          ..sort((a, b) {
            final left = _createdAtMillis[a.id] ?? 0;
            final right = _createdAtMillis[b.id] ?? 0;
            return right.compareTo(left);
          });
    return List.unmodifiable(active);
  }

  /// Stories grouped by author, with the signed-in user's group first.
  List<StoryGroup> get groups {
    final grouped = <String, List<StoryItem>>{};
    for (final story in items) {
      grouped.putIfAbsent(story.authorId, () => []).add(story);
    }
    final groups = grouped.entries
        .map((entry) => StoryGroup(authorId: entry.key, stories: entry.value))
        .toList();

    final uid = viewerId;
    groups.sort((a, b) {
      final mineA = a.isMine(uid) ? 0 : 1;
      final mineB = b.isMine(uid) ? 0 : 1;
      if (mineA != mineB) return mineA.compareTo(mineB);
      final left =
          _createdAtMillis[a.latest.id] ??
          a.latest.createdAt?.millisecondsSinceEpoch ??
          0;
      final right =
          _createdAtMillis[b.latest.id] ??
          b.latest.createdAt?.millisecondsSinceEpoch ??
          0;
      return right.compareTo(left);
    });
    return groups;
  }

  StoryGroup? get myGroup {
    final uid = viewerId;
    if (uid == null || uid.isEmpty) return null;
    for (final group in groups) {
      if (group.authorId == uid) return group;
    }
    return null;
  }

  Future<void> listen() async {
    if (Firebase.apps.isEmpty || _subscription != null || _starting) return;
    _starting = true;

    try {
      _viewerId = AuthService.instance.currentUser?.uid;
      await _loadSeen();
      if (!await _ensureGroup()) return;
      await _loadCache();
      if (_subscription != null) return;

      _subscription = _query.snapshots().listen(
        _onSnapshot,
        onError: (Object _) {},
      );
    } catch (_) {
      // Keep cached stories available when the network is unavailable.
    } finally {
      _starting = false;
    }
  }

  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection(_collection)
      .where('department', isEqualTo: _department)
      .where('level', isEqualTo: _level)
      .limit(_maxItems);

  Future<bool> _ensureGroup() async {
    if (_department.isNotEmpty && _level.isNotEmpty) return true;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
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

  Future<void> _loadSeen() async {
    final uid = viewerId;
    if (uid == null || uid.isEmpty) return;
    final seen = await LocalCache.instance.seenStoryIds(uid);
    _seenIds
      ..clear()
      ..addAll(seen);
  }

  Future<void> _loadCache() async {
    if (_hasLoaded) return;
    final cached = await LocalCache.instance.stories(_department, _level);
    if (cached == null || cached.isEmpty) return;

    for (final data in cached) {
      final story = _fromCachedMap(data);
      if (story.id.isEmpty) continue;
      _items.add(story);
      _createdAtMillis[story.id] = story.createdAt?.millisecondsSinceEpoch ?? 0;
    }
    _hasLoaded = true;
    notifyListeners();
  }

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
    final now = DateTime.now();
    final cutoff = now.subtract(_lifetime);
    final docs = snapshot.docs.where((doc) {
      if (_deletedIds.contains(doc.id)) return false;
      final createdAt = _dateFrom(doc.data()['createdAt']);
      return createdAt == null || createdAt.isAfter(cutoff);
    }).toList();

    final visibleIds = docs.map((doc) => doc.id).toSet();
    _seenIds.removeWhere(
      (id) => id.startsWith('story-') && !visibleIds.contains(id),
    );

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

  /// Uploads and publishes a story, then inserts it locally.
  ///
  /// [filePath] is the compressed media produced by the composer. Photos are
  /// uploaded as-is; videos have already been reduced with FFmpeg.
  Future<StoryItem> publish({
    required String filePath,
    required bool isVideo,
    String? caption,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('That story could not be read.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('That story is empty.');
    }
    if (bytes.length > 20 * 1024 * 1024) {
      throw StateError('That story is too large. Try a shorter video.');
    }

    if (Firebase.apps.isEmpty) {
      final now = DateTime.now();
      final story = StoryItem(
        id: 'story-local-${now.microsecondsSinceEpoch}',
        authorId: viewerId ?? 'local',
        username: 'You',
        storyImage: filePath,
        time: 'Just now',
        createdAt: now,
        caption: _cleanCaption(caption),
        isVideo: isVideo,
        hasUnread: false,
      );
      _insert(story);
      return story;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Your session expired. Sign in again to post a story.');
    }
    if (!await _ensureGroup()) {
      throw StateError(
        'Add your department and level to your profile before posting.',
      );
    }
    final profile = await AuthService.instance.currentUserProfile();
    final fullName = (profile?['fullName'] as String?)?.trim();
    final username = (profile?['username'] as String?)?.trim();
    final photoUrl = (profile?['photoUrl'] as String?)?.trim();
    final displayName = fullName != null && fullName.isNotEmpty
        ? fullName
        : username != null && username.isNotEmpty
        ? username
        : 'Encore user';
    final handle = _handleFor(username, displayName);

    final url = await _upload(
      bytes: bytes,
      isVideo: isVideo,
      sourcePath: filePath,
    );
    await ChatMediaCache.instance.saveLocalFile(
      url,
      filePath,
      folder: ChatMediaCache.storyFolder,
    );

    final doc = FirebaseFirestore.instance.collection(_collection).doc();
    final now = DateTime.now();
    final viewers = <String>[];
    final story = StoryItem(
      id: doc.id,
      authorId: uid,
      username: handle,
      avatarUrl: photoUrl,
      avatarText: _initials(displayName),
      avatarColor: _avatarColor(displayName),
      storyImage: url,
      time: 'Just now',
      createdAt: now,
      caption: _cleanCaption(caption),
      isVideo: isVideo,
      hasUnread: false,
      viewers: viewers,
      department: _department,
      level: _level,
    );

    await doc.set({
      'authorId': uid,
      'authorName': displayName,
      'username': handle,
      'photoUrl': photoUrl,
      'department': _department,
      'level': _level,
      'mediaUrl': url,
      'mediaType': isVideo ? 'video' : 'image',
      'caption': story.caption,
      'viewers': viewers,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(_lifetime)),
    });

    _insert(story);
    return story;
  }

  Future<String> _upload({
    required Uint8List bytes,
    required bool isVideo,
    required String sourcePath,
  }) async {
    final extension = isVideo ? 'mp4' : _photoExtension(sourcePath);
    final storage = MediaStorage(workerUrl: AppConfig.r2WorkerUrl);
    try {
      return await storage.upload(
        bytes: bytes,
        filename: 'story-${DateTime.now().microsecondsSinceEpoch}.$extension',
        contentType: isVideo ? 'video/mp4' : _photoContentType(extension),
      );
    } finally {
      storage.dispose();
    }
  }

  /// Marks a story as viewed for the current user and records the view.
  void markSeen(StoryItem story) {
    final changed = _seenIds.add(story.id);
    final uid = viewerId;
    final index = _items.indexWhere((item) => item.id == story.id);
    if (index >= 0 && uid != null && uid.isNotEmpty && !story.isMine(uid)) {
      final current = _items[index];
      if (!current.viewers.contains(uid)) {
        _items[index] = current.copyWith(
          hasUnread: false,
          viewers: [...current.viewers, uid],
        );
      }
    }
    if (changed) {
      unawaited(_saveSeen());
      notifyListeners();
    }
    if (Firebase.apps.isEmpty || uid == null || uid.isEmpty) return;
    if (story.authorId == uid || story.id.isEmpty) return;
    if (story.viewers.contains(uid)) return;
    unawaited(
      FirebaseFirestore.instance
          .collection(_collection)
          .doc(story.id)
          .update({
            'viewers': FieldValue.arrayUnion([uid]),
          })
          .catchError((Object _) {}),
    );
  }

  /// Deletes one of the signed-in user's stories.
  Future<void> delete(StoryItem story) async {
    final uid = viewerId;
    if (!story.isMine(uid)) return;

    if (Firebase.apps.isNotEmpty && story.id.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(_collection)
            .doc(story.id)
            .delete();
      } catch (_) {
        throw StateError('Could not delete that story. Try again.');
      }
    }

    _items.removeWhere((item) => item.id == story.id);
    _seenIds.remove(story.id);
    _deletedIds.add(story.id);
    _createdAtMillis.remove(story.id);
    notifyListeners();
    unawaited(_saveSeen());
    unawaited(_saveCache());
  }

  void _insert(StoryItem story) {
    _items.removeWhere((item) => item.id == story.id);
    _items.insert(0, story);
    _seenIds.add(story.id);
    _createdAtMillis[story.id] =
        story.createdAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    unawaited(_saveSeen());
    unawaited(_saveCache());
  }

  Future<void> _saveSeen() async {
    final uid = viewerId;
    if (uid == null || uid.isEmpty) return;
    await LocalCache.instance.saveSeenStoryIds(uid, _seenIds);
  }

  Future<void> _saveCache() {
    if (_department.isEmpty || _level.isEmpty) return Future<void>.value();
    return LocalCache.instance.saveStories(_department, _level, [
      for (final story in _items)
        {
          'id': story.id,
          'authorId': story.authorId,
          'username': story.username,
          'avatarUrl': story.avatarUrl,
          'avatarText': story.avatarText,
          'mediaUrl': story.storyImage,
          'mediaType': story.isVideo ? 'video' : 'image',
          'caption': story.caption,
          'viewers': story.viewers,
          'createdAt':
              _createdAtMillis[story.id] ??
              DateTime.now().millisecondsSinceEpoch,
        },
    ]);
  }

  StoryItem _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = _dateFrom(data['createdAt']);
    final authorId = data['authorId'] as String? ?? '';
    return StoryItem(
      id: doc.id,
      authorId: authorId,
      username: data['username'] as String? ?? 'Encore user',
      avatarUrl: (data['photoUrl'] as String?)?.trim(),
      avatarText: _initials(data['authorName'] as String? ?? ''),
      avatarColor: _avatarColor(data['authorName'] as String? ?? ''),
      storyImage: data['mediaUrl'] as String? ?? '',
      time: _formatAge(createdAt),
      createdAt: createdAt,
      caption: _cleanCaption(data['caption'] as String?),
      isVideo: data['mediaType'] == 'video',
      hasUnread: !_seenIds.contains(doc.id) && authorId != viewerId,
      viewers: _stringList(data['viewers']),
      department: data['department'] as String? ?? '',
      level: data['level'] as String? ?? '',
    );
  }

  StoryItem _fromCachedMap(Map<String, dynamic> data) {
    final createdAt = _dateFrom(data['createdAt']);
    final authorId = data['authorId'] as String? ?? '';
    final id = data['id'] as String? ?? '';
    return StoryItem(
      id: id,
      authorId: authorId,
      username: data['username'] as String? ?? 'Encore user',
      avatarUrl: (data['avatarUrl'] as String?)?.trim(),
      avatarText: (data['avatarText'] as String?)?.trim(),
      avatarColor: _avatarColor(data['avatarText'] as String? ?? ''),
      storyImage: data['mediaUrl'] as String? ?? '',
      time: _formatAge(createdAt),
      createdAt: createdAt,
      caption: _cleanCaption(data['caption'] as String?),
      isVideo: data['mediaType'] == 'video',
      hasUnread: !_seenIds.contains(id) && authorId != viewerId,
      viewers: _stringList(data['viewers']),
      department: _department,
      level: _level,
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  static String _handleFor(String? username, String fallback) {
    final value = username?.trim() ?? '';
    if (value.isEmpty) return fallback;
    if (value.startsWith('@') || value.startsWith('_')) return value;
    return '@$value';
  }

  static String? _cleanCaption(String? caption) {
    final value = caption?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _photoExtension(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot >= 0 ? path.substring(dot + 1).toLowerCase() : '';
    return switch (ext) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
  }

  static String _photoContentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  static List<String> _stringList(Object? value) {
    return switch (value) {
      List list => list.whereType<String>().toList(),
      _ => const [],
    };
  }

  static Color _avatarColor(String seed) {
    const palette = [
      Color(0xFF1F7A4D),
      Color(0xFF1F5F8B),
      Color(0xFF7A4D9E),
      Color(0xFF9E4D5B),
      Color(0xFF8B6A1F),
      Color(0xFF3D6B8B),
    ];
    final value = seed.trim().isEmpty ? 'Encore user' : seed.trim();
    final sum = value.codeUnits.fold<int>(0, (total, unit) => total + unit);
    return palette[sum % palette.length];
  }

  static String _formatAge(DateTime? time) {
    if (time == null) return 'Just now';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '1d ago';
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
}
