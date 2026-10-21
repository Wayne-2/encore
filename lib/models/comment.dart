/// A comment in a post's thread (announcement or trending).
class Comment {
  const Comment({
    this.id = '',
    this.authorId = '',
    required this.name,
    required this.handle,
    required this.time,
    required this.text,
    required this.initials,
    this.photoUrl,
    this.createdAt,
    this.reactions = const {},
    this.replyToId = '',
    this.replyToName = '',
    this.replyToText = '',
  });

  final String id;
  final String authorId;
  final String name;
  final String handle;
  final String time;
  final String text;
  final String initials;
  final String? photoUrl;
  final DateTime? createdAt;

  /// Initial emoji tallies, keyed by emoji.
  final Map<String, int> reactions;

  /// Set when this comment replies to another comment in the same thread.
  final String replyToId;
  final String replyToName;
  final String replyToText;
}
