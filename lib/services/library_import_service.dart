import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../config/app_config.dart';
import '../models/library_material.dart';
import 'media_storage.dart';

/// Turns a picked PDF or image into a text-first library document.
///
/// The original file is never uploaded or kept. PDF text comes from pdfrx's
/// text layer, images go through ML Kit OCR, and only the extracted document
/// is saved to the public library (plus a `.txt` copy in R2).
class LibraryImportService {
  LibraryImportService._();

  static final LibraryImportService instance = LibraryImportService._();

  static const int maxUploadBytes = 20 * 1024 * 1024;

  /// Firestore documents cap out around 1 MiB, so keep the searchable copy
  /// comfortably below that. The `.txt` upload keeps the full extraction.
  static const int maxStoredTextChars = 700000;

  Future<LibraryMaterial> import({
    required PlatformFile file,
    required String id,
    required String uploaderId,
    required String uploaderName,
    String? title,
    String subject = '',
  }) async {
    final kind = _fileKind((file.extension ?? '').toLowerCase());
    if (kind == null) {
      throw const LibraryImportException('Choose a PDF, PNG or JPG file.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const LibraryImportException('That file is empty.');
    }
    if (bytes.length > maxUploadBytes) {
      throw const LibraryImportException('Choose a file smaller than 20 MB.');
    }

    final extractedText = switch (kind) {
      LibraryMaterialKind.pdf => await _extractPdfText(bytes, file.name),
      LibraryMaterialKind.image => await _extractImageText(file, bytes),
    };
    if (extractedText.trim().isEmpty) {
      throw const LibraryImportException(
        'No readable text was found in that file.',
      );
    }

    final resolvedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : _titleFromFileName(file.name);
    final resolvedSubject = subject.trim();
    final baseName = _safeBaseName(file.name);
    final textFileName = '$id-$baseName.txt';
    final header = resolvedSubject.isEmpty
        ? '$resolvedTitle\n\n'
        : '$resolvedTitle\n$resolvedSubject\n\n';
    final textBytes = utf8.encode('$header$extractedText');
    final storedText = extractedText.length > maxStoredTextChars
        ? '${extractedText.substring(0, maxStoredTextChars)}\n\n'
              '[Text shortened for the in-app reader. The full text is '
              'available in $textFileName.]'
        : extractedText;

    final storage = MediaStorage(workerUrl: AppConfig.r2WorkerUrl);
    try {
      final textUrl = await storage.upload(
        bytes: textBytes,
        filename: textFileName,
        contentType: 'text/plain; charset=utf-8',
      );
      await _saveTextFile(textFileName, textBytes);

      return LibraryMaterial(
        id: id,
        title: resolvedTitle,
        fileName: file.name,
        kind: kind,
        subject: resolvedSubject,
        extractedText: storedText,
        textUrl: textUrl,
        textFileName: textFileName,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
        createdAt: DateTime.now(),
      );
    } finally {
      storage.dispose();
    }
  }

  Future<String> _extractPdfText(Uint8List bytes, String fileName) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(bytes, sourceName: fileName);
    try {
      final buffer = StringBuffer();
      for (final page in document.pages) {
        final pageText = await page.loadText();
        final text = _cleanText(pageText?.fullText ?? '');
        if (text.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(text);
      }
      return _cleanText(buffer.toString());
    } finally {
      await document.dispose();
    }
  }

  Future<String> _extractImageText(PlatformFile file, Uint8List bytes) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final path = await _localImagePath(file, bytes);
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return _cleanText(result.text);
    } finally {
      await recognizer.close();
    }
  }

  Future<String> _localImagePath(PlatformFile file, Uint8List bytes) async {
    final path = file.path;
    if (path != null && await File(path).exists()) return path;

    final directory = await getTemporaryDirectory();
    final target = File(
      '${directory.path}/${DateTime.now().microsecondsSinceEpoch}-'
      '${_safeFileName(file.name)}',
    );
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<void> _saveTextFile(String fileName, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/library_texts');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final target = File('${folder.path}/$fileName');
    await target.writeAsBytes(bytes, flush: true);
  }

  static String _cleanText(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _titleFromFileName(String fileName) {
    final withoutExtension = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final spaced = withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return spaced.isEmpty ? 'Untitled document' : spaced;
  }

  static String _safeBaseName(String fileName) {
    final withoutExtension = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final safe = withoutExtension.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return safe.isEmpty ? 'document' : safe;
  }

  static String _safeFileName(String fileName) {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safe.isEmpty ? 'upload' : safe;
  }

  static LibraryMaterialKind? _fileKind(String extension) {
    return switch (extension) {
      'pdf' => LibraryMaterialKind.pdf,
      'png' || 'jpg' || 'jpeg' => LibraryMaterialKind.image,
      _ => null,
    };
  }
}

class LibraryImportException implements Exception {
  const LibraryImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
