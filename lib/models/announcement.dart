import 'package:flutter/material.dart';

/// A single announcement shown in the Updates feed.
class Announcement {
  const Announcement({
    required this.author,
    required this.time,
    required this.tag,
    required this.tagColor,
    required this.body,
    this.unread = false,
  });

  final String author;
  final String time;

  /// Priority label shown under the author, e.g. "Highly prior".
  final String tag;
  final Color tagColor;
  final String body;
  final bool unread;
}
