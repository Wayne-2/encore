import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Uploads media to Cloudflare R2 using presigned URLs issued by a Worker.
///
/// The Worker holds the R2 credentials and returns a short-lived PUT URL; the
/// bytes never pass through the Worker and the access keys never ship in the
/// app. Pair it with [AppConfig.r2WorkerUrl].
class MediaStorage {
  MediaStorage({required String workerUrl, http.Client? client})
    : _workerUrl = workerUrl.replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String _workerUrl;
  final http.Client _client;

  /// Requests a presigned URL for [filename] and PUTs [bytes] to R2.
  ///
  /// Returns the public URL of the uploaded object.
  Future<String> upload({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final signRes = await _client.post(
      Uri.parse('$_workerUrl/sign'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'filename': filename, 'contentType': contentType}),
    );

    if (signRes.statusCode != 200) {
      throw MediaStorageException(
        'Failed to sign upload (${signRes.statusCode}): ${signRes.body}',
      );
    }

    final data = jsonDecode(signRes.body) as Map<String, dynamic>;
    final uploadUrl = data['uploadUrl'] as String;
    final publicUrl = data['publicUrl'] as String;

    final putRes = await _client.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': ?contentType},
      body: bytes,
    );

    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      throw MediaStorageException(
        'Failed to upload to R2 (${putRes.statusCode}): ${putRes.body}',
      );
    }

    return publicUrl;
  }

  /// Releases the underlying HTTP client.
  void dispose() => _client.close();
}

/// Thrown when signing or uploading to R2 fails.
class MediaStorageException implements Exception {
  MediaStorageException(this.message);

  final String message;

  @override
  String toString() => 'MediaStorageException: $message';
}
