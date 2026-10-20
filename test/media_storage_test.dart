import 'dart:convert';
import 'dart:typed_data';

import 'package:encore/services/media_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('upload posts bytes to the Worker and returns the public URL', () async {
    late http.Request captured;
    final storage = MediaStorage(
      workerUrl: 'https://worker.example/',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'publicUrl': 'https://worker.example/media/a.png'}),
          200,
        );
      }),
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final url = await storage.upload(
      bytes: bytes,
      filename: 'my photo.png',
      contentType: 'image/png',
    );

    expect(url, 'https://worker.example/media/a.png');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/upload');
    expect(captured.url.queryParameters['filename'], 'my photo.png');
    expect(captured.headers['Content-Type'], 'image/png');
    expect(captured.bodyBytes, bytes);
  });

  test('upload throws when the Worker rejects the request', () async {
    final storage = MediaStorage(
      workerUrl: 'https://worker.example',
      client: MockClient((_) async => http.Response('nope', 500)),
    );

    await expectLater(
      storage.upload(
        bytes: Uint8List.fromList([1]),
        filename: 'a.png',
        contentType: 'image/png',
      ),
      throwsA(isA<MediaStorageException>()),
    );
  });
}
