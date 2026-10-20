import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Uploads media to Cloudflare R2 through the media Worker.
///
/// The Worker writes the bytes to its R2 binding and serves them back through
/// `/media`; no storage credentials ship in the app. Pair it with
/// [AppConfig.r2WorkerUrl].
class MediaStorage {
  MediaStorage({required String workerUrl, http.Client? client})
    : _workerUrl = workerUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String _workerUrl;
  final http.Client _client;

  /// Uploads [bytes] and returns the public URL of the stored object.
  Future<String> upload({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final uploadUri = Uri.parse(
      '$_workerUrl/upload',
    ).replace(queryParameters: {'filename': filename});

    final res = await _client.post(
      uploadUri,
      headers: {'Content-Type': ?contentType},
      body: bytes,
    );

    if (res.statusCode != 200) {
      throw MediaStorageException(
        'Failed to upload to R2 (${res.statusCode}): ${res.body}',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['publicUrl'] as String;
  }

  /// Releases the underlying HTTP client.
  void dispose() => _client.close();
}

/// Thrown when uploading to R2 fails.
class MediaStorageException implements Exception {
  MediaStorageException(this.message);

  final String message;

  @override
  String toString() => 'MediaStorageException: $message';
}
