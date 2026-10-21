import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// WhatsApp-style on-device cache for chat attachments.
///
/// Voice notes and photos are written to the app's support directory as soon
/// as a message arrives, then every bubble renders the local file first. The
/// network is only used when a file is not on the device yet.
class ChatMediaCache {
  ChatMediaCache._();

  static final ChatMediaCache instance = ChatMediaCache._();

  static const String _rootFolder = 'encore_chat_media';
  static const String voiceFolder = 'voice';
  static const String imageFolder = 'images';
  static const int _maxCacheBytes = 300 * 1024 * 1024;

  final Map<String, Future<File?>> _inFlight = {};
  final Set<String> _prefetched = {};
  final http.Client _client = http.Client();
  Directory? _root;

  Future<Directory> _directory(String folder) async {
    final root = _root ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/$_rootFolder',
    );
    final dir = Directory('${root.path}/$folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The cached file for [url], or null when it has not been downloaded.
  Future<File?> fileFor(String url, {String folder = voiceFolder}) async {
    if (url.trim().isEmpty) return null;
    final dir = await _directory(folder);
    final file = File('${dir.path}/${_fileName(url)}');
    return await file.exists() ? file : null;
  }

  /// Returns the local file for [url], downloading it once when needed.
  Future<File?> ensureDownloaded(
    String url, {
    String folder = voiceFolder,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final cached = await fileFor(trimmed, folder: folder);
    if (cached != null) return cached;

    final existing = _inFlight[trimmed];
    if (existing != null) return existing;

    final future = _download(trimmed, folder: folder);
    _inFlight[trimmed] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(trimmed);
    }
  }

  /// Starts background downloads for every voice note in a message batch.
  ///
  /// Recipients therefore already have the audio on disk when they open the
  /// bubble, instead of waiting for a stream to buffer over the network.
  Future<void> prefetchVoiceNotes(Iterable<String?> urls) async {
    final pending = <Future<File?>>[];
    for (final url in urls) {
      final value = url?.trim();
      if (value == null || value.isEmpty || !_prefetched.add(value)) continue;
      pending.add(_prefetch(value, voiceFolder));
    }
    if (pending.isNotEmpty) await Future.wait(pending, eagerError: false);
  }

  /// Prefetches image attachments too, so chat photos open from disk.
  Future<void> prefetchImages(Iterable<String?> urls) async {
    final pending = <Future<File?>>[];
    for (final url in urls) {
      final value = url?.trim();
      if (value == null || value.isEmpty || !_prefetched.add(value)) continue;
      pending.add(_prefetch(value, imageFolder));
    }
    if (pending.isNotEmpty) await Future.wait(pending, eagerError: false);
  }

  Future<File?> _prefetch(String url, String folder) async {
    final file = await ensureDownloaded(url, folder: folder);
    if (file == null) _prefetched.remove(url);
    return file;
  }

  /// Keeps a locally recorded/sent file under the URL returned by storage.
  Future<void> saveLocalFile(
    String url,
    String sourcePath, {
    String folder = voiceFolder,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) return;
    final dir = await _directory(folder);
    final target = File('${dir.path}/${_fileName(url)}');
    if (target.path == source.path) return;
    try {
      await source.copy(target.path);
      _prefetched.add(url);
      unawaited(_trim(dir));
    } catch (_) {
      // A cache copy is optional; playback can still use the source file.
    }
  }

  Future<File?> _download(String url, {required String folder}) async {
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;

      final dir = await _directory(folder);
      final target = File('${dir.path}/${_fileName(url)}');
      final temp = File('${target.path}.part');
      await temp.writeAsBytes(response.bodyBytes, flush: true);
      await temp.rename(target.path);
      unawaited(_trim(dir));
      return target;
    } catch (_) {
      return null;
    }
  }

  Future<void> _trim(Directory dir) async {
    try {
      final files = await dir
          .list()
          .where((entity) => entity is File && !entity.path.endsWith('.part'))
          .cast<File>()
          .toList();
      if (files.isEmpty) return;

      var total = 0;
      final stats = <({File file, int size, DateTime modified})>[];
      for (final file in files) {
        final stat = await file.stat();
        total += stat.size;
        stats.add((file: file, size: stat.size, modified: stat.modified));
      }
      if (total <= _maxCacheBytes) return;

      stats.sort((a, b) => a.modified.compareTo(b.modified));
      for (final entry in stats) {
        if (total <= _maxCacheBytes) break;
        try {
          await entry.file.delete();
          total -= entry.size;
        } catch (_) {
          // Keep trimming the remaining files.
        }
      }
    } catch (_) {
      // Cache trimming is best effort.
    }
  }

  static String _fileName(String url) {
    final uri = Uri.tryParse(url);
    final segment = uri == null || uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last;
    final dot = segment.lastIndexOf('.');
    final extension = dot >= 0 && segment.length - dot <= 6
        ? segment.substring(dot + 1).toLowerCase()
        : 'bin';
    return '${_fnv1a(url)}.$extension';
  }

  static String _fnv1a(String value) {
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
