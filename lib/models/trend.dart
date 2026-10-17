/// A trending topic shown in the Updates "Trending" row.
class Trend {
  const Trend({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.author,
    required this.time,
    required this.body,
  });

  final String image;
  final String title;
  final String subtitle;
  final String author;
  final String time;
  final String body;
}
