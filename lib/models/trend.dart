import 'dart:typed_data';

/// Media attached to a trend post.
///
/// Locally composed trends carry a thumbnail in memory for an instant preview;
/// persisted trends carry the uploaded [url] instead.
class TrendMedia {
  const TrendMedia({
    this.thumbnail,
    this.url = '',
    this.isVideo = false,
    this.duration = Duration.zero,
  });

  final Uint8List? thumbnail;
  final String url;
  final bool isVideo;
  final Duration duration;
}

/// A trending post shown in the Updates "Trending" row.
class Trend {
  const Trend({
    this.id = '',
    this.authorId = '',
    required this.title,
    required this.subtitle,
    required this.author,
    required this.time,
    required this.body,
    this.media = const [],
  });

  final String id;
  final String authorId;
  final String title;
  final String subtitle;
  final String author;
  final String time;
  final String body;
  final List<TrendMedia> media;

  /// Whether [userId] is the author and may therefore delete this trend.
  bool canBeDeletedBy(String? userId) =>
      userId != null && userId.isNotEmpty && userId == authorId;
}
