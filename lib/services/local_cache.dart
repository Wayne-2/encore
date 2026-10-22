import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Small Hive-backed cache for feeds, chats, contacts and the signed-in profile.
///
/// Values are stored as JSON strings in a single box so no generated adapters
/// are required. Missing initialization (for example in widget tests) simply
/// makes reads return null and writes no-ops; the app keeps working online.
class LocalCache {
  LocalCache._();

  static final LocalCache instance = LocalCache._();

  static const String _boxName = 'encore_local_cache_v1';
  static const String _imageBoxName = 'encore_image_cache_v1';
  static const int _maxCachedImages = 120;

  Box<String>? _box;
  Box<Uint8List>? _imageBox;
  Future<void>? _opening;

  bool get isReady => _box?.isOpen ?? false;

  /// Opens Hive on disk. Safe to call more than once.
  Future<void> init() {
    return _opening ??= _open();
  }

  Future<void> _open() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(_boxName);
      _imageBox = await Hive.openBox<Uint8List>(_imageBoxName);
    } catch (_) {
      // Keep the cache optional; the stores still fetch from Firestore.
      _box = null;
      _imageBox = null;
    }
  }

  Future<dynamic> read(String key) async {
    final box = _box;
    if (box == null) return null;

    final raw = box.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object? value) async {
    final box = _box;
    if (box == null) return;

    try {
      await box.put(key, jsonEncode(_jsonSafe(value)));
    } catch (_) {
      // Cache writes are best effort.
    }
  }

  Future<void> delete(String key) async {
    final box = _box;
    if (box == null) return;
    try {
      await box.delete(key);
    } catch (_) {
      // Best effort.
    }
  }

  // -------------------------------------------------------------------------
  // Profiles
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> profile(String uid) async {
    final value = await read('profile:$uid');
    return value is Map ? _stringMap(value) : null;
  }

  Future<void> saveProfile(String uid, Map<String, dynamic> data) {
    return write('profile:$uid', data);
  }

  // -------------------------------------------------------------------------
  // Announcements (scoped to the user's department + level)
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>?> announcements(
    String department,
    String level,
  ) async {
    final value = await read(_announcementsKey(department, level));
    return _mapList(value);
  }

  Future<void> saveAnnouncements(
    String department,
    String level,
    List<Map<String, dynamic>> items,
  ) {
    return write(_announcementsKey(department, level), items);
  }

  static String _announcementsKey(String department, String level) {
    return 'announcements:${department.trim().toLowerCase()}:'
        '${level.trim().toLowerCase()}';
  }

  // -------------------------------------------------------------------------
  // Stories (scoped to the user's department + level)
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>?> stories(
    String department,
    String level,
  ) async {
    final value = await read(_storiesKey(department, level));
    return _mapList(value);
  }

  Future<void> saveStories(
    String department,
    String level,
    List<Map<String, dynamic>> items,
  ) {
    return write(_storiesKey(department, level), items);
  }

  static String _storiesKey(String department, String level) {
    return 'stories:${department.trim().toLowerCase()}:'
        '${level.trim().toLowerCase()}';
  }

  Future<Set<String>> seenStoryIds(String viewerId) async {
    final value = await read('storySeen:$viewerId');
    if (value is! List) return <String>{};
    return value.whereType<String>().toSet();
  }

  Future<void> saveSeenStoryIds(String viewerId, Set<String> ids) {
    return write('storySeen:$viewerId', ids.toList());
  }

  // -------------------------------------------------------------------------
  // Trends
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>?> trends() async {
    return _mapList(await read('trends'));
  }

  Future<void> saveTrends(List<Map<String, dynamic>> items) {
    return write('trends', items);
  }

  // -------------------------------------------------------------------------
  // Activities
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>?> activities() async {
    return _mapList(await read('activities'));
  }

  Future<void> saveActivities(List<Map<String, dynamic>> items) {
    return write('activities', items);
  }

  // -------------------------------------------------------------------------
  // Personal todos (scoped to the signed-in account)
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>?> todos(String uid) async {
    return _mapList(await read('todos:$uid'));
  }

  Future<void> saveTodos(String uid, List<Map<String, dynamic>> items) {
    return write('todos:$uid', items);
  }

  // -------------------------------------------------------------------------
  // Direct messages (scoped to the signed-in account)
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>?> chats(String uid) async {
    return _mapList(await read('chats:$uid'));
  }

  Future<void> saveChats(String uid, List<Map<String, dynamic>> items) {
    return write('chats:$uid', items);
  }

  Future<Map<String, dynamic>?> chat(String uid, String chatId) async {
    final value = await read('chat:$uid:$chatId');
    return value is Map ? _stringMap(value) : null;
  }

  Future<void> saveChat(String uid, String chatId, Map<String, dynamic> data) {
    return write('chat:$uid:$chatId', data);
  }

  Future<List<Map<String, dynamic>>?> messages(
    String uid,
    String chatId,
  ) async {
    return _mapList(await read('messages:$uid:$chatId'));
  }

  Future<void> saveMessages(
    String uid,
    String chatId,
    List<Map<String, dynamic>> items,
  ) {
    return write('messages:$uid:$chatId', items);
  }

  Future<List<Map<String, dynamic>>?> contactRequests(String uid) async {
    return _mapList(await read('contactRequests:$uid'));
  }

  Future<void> saveContactRequests(
    String uid,
    List<Map<String, dynamic>> items,
  ) {
    return write('contactRequests:$uid', items);
  }

  Future<List<Map<String, dynamic>>?> users() async {
    return _mapList(await read('users'));
  }

  Future<void> saveUsers(List<Map<String, dynamic>> items) {
    return write('users', items);
  }

  // -------------------------------------------------------------------------
  // Profile images (bytes keyed by URL)
  // -------------------------------------------------------------------------

  /// Returns the Hive-cached bytes for [url], if the image was seen before.
  Uint8List? imageBytes(String url) {
    final box = _imageBox;
    if (box == null || url.isEmpty) return null;
    return box.get(url);
  }

  Future<void> saveImageBytes(String url, Uint8List bytes) async {
    final box = _imageBox;
    if (box == null || url.isEmpty) return;
    try {
      await box.put(url, bytes);
      final excess = box.length - _maxCachedImages;
      if (excess > 0) {
        for (final key in box.keys.take(excess)) {
          if (key != url) await box.delete(key);
        }
      }
    } catch (_) {
      // Image caching is best effort.
    }
  }

  Future<void> deleteImageBytes(String url) async {
    final box = _imageBox;
    if (box == null) return;
    try {
      await box.delete(url);
    } catch (_) {
      // Best effort.
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static List<Map<String, dynamic>>? _mapList(Object? value) {
    if (value is! List) return null;
    return [
      for (final item in value)
        if (item is Map) _stringMap(item),
    ];
  }

  static Map<String, dynamic> _stringMap(Map value) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  /// Converts Firestore-specific values (timestamps, nested maps) into
  /// JSON-safe primitives before storing.
  static Object? _jsonSafe(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) {
      return [for (final item in value) _jsonSafe(item)];
    }
    return value.toString();
  }
}
