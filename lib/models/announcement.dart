import 'package:flutter/material.dart';

/// A single announcement shown in the Updates feed.
class Announcement {
  const Announcement({
    required this.author,
    required this.time,
    required this.tag,
    required this.tagColor,
    required this.body,
    this.id = '',
    this.authorId = '',
    this.photoUrl,
    this.unread = false,
    this.createdAt,
  });

  /// Stable identity for list keys and entrance animations.
  final String id;

  final String author;

  /// The uid of the user who posted the announcement.
  final String authorId;

  /// The poster's profile picture, if they have one.
  final String? photoUrl;

  final String time;

  /// Priority label shown under the author, e.g. "Highly prior".
  final String tag;
  final Color tagColor;
  final String body;
  final bool unread;
  final DateTime? createdAt;

  /// Whether [userId] is the author and may therefore delete this post.
  bool canBeDeletedBy(String? userId) =>
      userId != null && userId.isNotEmpty && userId == authorId;

  Announcement copyWith({bool? unread}) {
    return Announcement(
      id: id,
      author: author,
      authorId: authorId,
      photoUrl: photoUrl,
      time: time,
      tag: tag,
      tagColor: tagColor,
      body: body,
      unread: unread ?? this.unread,
      createdAt: createdAt,
    );
  }
}
