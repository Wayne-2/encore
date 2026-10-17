/// A comment in a post's thread (announcement or trending).
class Comment {
  const Comment({
    required this.name,
    required this.handle,
    required this.time,
    required this.text,
    required this.initials,
    this.reactions = const {},
  });

  final String name;
  final String handle;
  final String time;
  final String text;
  final String initials;

  /// Initial emoji tallies, keyed by emoji.
  final Map<String, int> reactions;
}
