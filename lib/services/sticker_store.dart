import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';
import 'local_cache.dart';

/// A WebP sticker imported from a WhatsApp sticker folder.
class StickerItem {
  const StickerItem({
    required this.id,
    required this.path,
    required this.name,
    required this.pack,
  });

  final String id;
  final String path;
  final String name;
  final String pack;

  factory StickerItem.fromMap(Map<String, dynamic> data) {
    return StickerItem(
      id: data['id'] as String? ?? '',
      path: data['path'] as String? ?? '',
      name: data['name'] as String? ?? '',
      pack: data['pack'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'path': path, 'name': name, 'pack': pack};
  }
}

/// Raw sticker bytes selected from the device.
class StickerSource {
  const StickerSource({
    required this.name,
    required this.bytes,
    this.pack = '',
  });

  final String name;
  final Uint8List bytes;
  final String pack;
}

/// Outcome of an import, used for user-facing feedback.
class StickerImportResult {
  const StickerImportResult({this.imported = 0, this.skipped = 0, this.error});

  final int imported;
  final int skipped;
  final String? error;

  int get found => imported + skipped;
  bool get isSuccess => error == null;
}

/// Locally imported WhatsApp stickers.
///
/// Stickers live in the app's support directory and the list is cached in
/// Hive. The files are copied so removing the original WhatsApp folder does
/// not break the keyboard.
class StickerStore {
  StickerStore._();

  static final StickerStore instance = StickerStore._();

  static const int _maxStickerBytes = 4 * 1024 * 1024;
  static const int _maxImportFiles = 600;

  List<StickerItem> _items = const [];
  String? _loadedFor;
  Directory? _rootOverride;

  List<StickerItem> get items => List.unmodifiable(_items);

  String get _owner => AuthService.instance.currentUser?.uid ?? 'local';
  String get _cacheKey => 'stickers:$_owner';

  @visibleForTesting
  void useRootForTesting(Directory? directory) {
    _rootOverride = directory;
    _items = const [];
    _loadedFor = null;
  }

  Future<List<StickerItem>> load({bool refresh = false}) async {
    final key = _cacheKey;
    if (!refresh && _loadedFor == key) return items;

    final raw = await LocalCache.instance.read(key);
    final loaded = <StickerItem>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final item = StickerItem.fromMap(Map<String, dynamic>.from(entry));
        if (item.id.isEmpty || item.path.isEmpty) continue;
        if (!await File(item.path).exists()) continue;
        loaded.add(item);
      }
    }

    _items = loaded;
    _loadedFor = key;
    return items;
  }

  /// Imports every `.webp` sticker in [directoryPath], including subfolders.
  Future<StickerImportResult> importDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return const StickerImportResult(
        error: 'That folder could not be opened.',
      );
    }

    final sources = <StickerSource>[];
    final pack = _baseName(directoryPath);
    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !_isWebpPath(entity.path)) continue;
        if (sources.length >= _maxImportFiles) break;
        try {
          final bytes = await entity.readAsBytes();
          sources.add(
            StickerSource(
              name: _baseName(entity.path),
              bytes: bytes,
              pack: pack,
            ),
          );
        } catch (_) {
          // Skip unreadable files and keep importing the rest.
        }
      }
    } catch (_) {
      return StickerImportResult(
        error: sources.isEmpty
            ? 'That folder could not be read. Choose the sticker files '
                  'directly instead.'
            : null,
      );
    }

    if (sources.isEmpty) {
      return const StickerImportResult(
        error: 'No .webp stickers were found in that folder.',
      );
    }
    return importSources(sources);
  }

  /// Copies and records selected sticker sources.
  Future<StickerImportResult> importSources(List<StickerSource> sources) async {
    await load();
    if (sources.isEmpty) {
      return const StickerImportResult(
        error: 'No .webp stickers were selected.',
      );
    }

    final directory = await _stickerDirectory();
    final imported = <StickerItem>[];
    final seen = <String>{};
    var skipped = 0;

    for (final source in sources.take(_maxImportFiles)) {
      if (source.bytes.isEmpty ||
          source.bytes.length > _maxStickerBytes ||
          !_isWebpBytes(source.bytes)) {
        skipped++;
        continue;
      }

      final id = _hash(source.bytes);
      if (!seen.add(id) || _items.any((item) => item.id == id)) {
        skipped++;
        continue;
      }

      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        final target = File('${directory.path}/$id.webp');
        await target.writeAsBytes(source.bytes, flush: true);
        imported.add(
          StickerItem(
            id: id,
            path: target.path,
            name: source.name,
            pack: source.pack,
          ),
        );
      } catch (_) {
        skipped++;
      }
    }

    if (imported.isNotEmpty) {
      _items = [..._items, ...imported];
      await _save();
    }

    return StickerImportResult(
      imported: imported.length,
      skipped: skipped,
      error: imported.isEmpty && skipped > 0
          ? 'Those files were not valid WhatsApp stickers.'
          : null,
    );
  }

  Future<void> remove(StickerItem item) async {
    _items = _items
        .where((entry) => entry.id != item.id)
        .toList(growable: false);
    await _save();
    try {
      final file = File(item.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Removing the record is enough; the file is harmless if it remains.
    }
  }

  Future<void> _save() {
    return LocalCache.instance.write(_cacheKey, [
      for (final item in _items) item.toMap(),
    ]);
  }

  Future<Directory> _stickerDirectory() async {
    final override = _rootOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/encore_stickers/$_owner');
  }

  static bool _isWebpPath(String path) {
    return path.toLowerCase().endsWith('.webp');
  }

  static bool _isWebpBytes(List<int> bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }

  static String _hash(List<int> bytes) {
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final index = trimmed.lastIndexOf('/');
    final name = index >= 0 ? trimmed.substring(index + 1) : trimmed;
    return name.trim().isEmpty ? 'Stickers' : name;
  }
}
