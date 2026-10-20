import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Small Hive-backed cache for the feeds and the signed-in profile.
///
/// Values are stored as JSON strings in a single box so no generated adapters
/// are required. Missing initialization (for example in widget tests) simply
/// makes reads return null and writes no-ops; the app keeps working online.
class LocalCache {
  LocalCache._();

  static final LocalCache instance = LocalCache._();

  static const String _boxName = 'encore_local_cache_v1';

  Box<String>? _box;
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
    } catch (_) {
      // Keep the cache optional; the stores still fetch from Firestore.
      _box = null;
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
