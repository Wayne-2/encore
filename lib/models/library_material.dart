import 'package:cloud_firestore/cloud_firestore.dart';

enum LibraryMaterialKind { pdf, image }

LibraryMaterialKind libraryMaterialKindFrom(Object? value) =>
    value == 'image' ? LibraryMaterialKind.image : LibraryMaterialKind.pdf;

DateTime? parseLibraryTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String formatCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class LibraryMaterial {
  const LibraryMaterial({
    required this.id,
    required this.title,
    required this.fileName,
    required this.kind,
    required this.extractedText,
    this.subject = '',
    this.textUrl = '',
    this.textFileName = '',
    this.uploaderId = '',
    this.uploaderName = '',
    this.createdAt,
    this.isDemo = false,
  });

  final String id;
  final String title;
  final String fileName;
  final LibraryMaterialKind kind;
  final String subject;
  final String extractedText;
  final String textUrl;
  final String textFileName;
  final String uploaderId;
  final String uploaderName;
  final DateTime? createdAt;
  final bool isDemo;

  bool get isPdf => kind == LibraryMaterialKind.pdf;
  bool get hasText => extractedText.trim().isNotEmpty;
  String get subjectLabel => subject.trim();
  String get sourceLabel => isPdf ? 'PDF source' : 'Image scan';

  int get wordCount => RegExp(r'\S+').allMatches(extractedText).length;

  int get readMinutes {
    final minutes = (wordCount / 220).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  String get wordLabel {
    final count = wordCount;
    return '${formatCount(count)} ${count == 1 ? 'word' : 'words'}';
  }

  String get readTimeLabel {
    final minutes = readMinutes;
    return '$minutes min read';
  }

  String get metaLabel => '$wordLabel · $readTimeLabel';

  factory LibraryMaterial.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LibraryMaterial(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : (data['fileName'] as String?)?.trim() ?? 'Untitled document',
      fileName: data['fileName'] as String? ?? '',
      kind: libraryMaterialKindFrom(data['kind']),
      subject: data['subject'] as String? ?? '',
      extractedText: data['extractedText'] as String? ?? '',
      textUrl: data['textUrl'] as String? ?? '',
      textFileName: data['textFileName'] as String? ?? '',
      uploaderId: data['uploaderId'] as String? ?? '',
      uploaderName: data['uploaderName'] as String? ?? '',
      createdAt: parseLibraryTimestamp(data['createdAt']),
    );
  }
}

class LibraryHighlight {
  const LibraryHighlight({
    required this.id,
    required this.materialId,
    required this.materialTitle,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String materialId;
  final String materialTitle;
  final String text;
  final DateTime? createdAt;

  factory LibraryHighlight.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LibraryHighlight(
      id: doc.id,
      materialId: data['materialId'] as String? ?? '',
      materialTitle: data['materialTitle'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: parseLibraryTimestamp(data['createdAt']),
    );
  }
}

class LibraryHistoryEntry {
  const LibraryHistoryEntry({
    required this.materialId,
    required this.title,
    required this.kind,
    required this.readCount,
    this.progress = 0,
    this.lastReadAt,
  });

  final String materialId;
  final String title;
  final LibraryMaterialKind kind;
  final int readCount;

  /// How far through the document the reader got, from 0 to 1.
  final double progress;
  final DateTime? lastReadAt;

  factory LibraryHistoryEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final progress = (data['progress'] as num?)?.toDouble() ?? 0;
    return LibraryHistoryEntry(
      materialId: data['materialId'] as String? ?? doc.id,
      title: data['title'] as String? ?? '',
      kind: libraryMaterialKindFrom(data['kind']),
      readCount: (data['readCount'] as num?)?.toInt() ?? 1,
      progress: progress.clamp(0.0, 1.0),
      lastReadAt: parseLibraryTimestamp(data['lastReadAt']),
    );
  }
}
