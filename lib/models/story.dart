import 'package:flutter/material.dart';

/// A single story / status item shown in the horizontal `# Story` reel.
///
/// Stories are scoped to the author's department + level group and expire
/// after 24 hours. [storyImage] may be a bundled asset (demo stories) or a
/// remote R2 URL (posted stories).
class StoryItem {
  const StoryItem({
    required this.id,
    required this.username,
    this.authorId = '',
    this.avatarAsset,
    this.avatarUrl,
    this.avatarColor,
    this.avatarText,
    this.hasUnread = true,
    required this.storyImage,
    required this.time,
    this.createdAt,
    this.caption,
    this.isVideo = false,
    this.viewers = const [],
    this.hiddenFrom = const [],
    this.department = '',
    this.level = '',
  });

  final String id;
  final String authorId;
  final String username;
  final String? avatarAsset;
  final String? avatarUrl;
  final Color? avatarColor;
  final String? avatarText;
  final bool hasUnread;
  final String storyImage;
  final String time;
  final DateTime? createdAt;
  final String? caption;
  final bool isVideo;
  final List<String> viewers;

  /// UIDs of contacts who should not see this story.
  final List<String> hiddenFrom;
  final String department;
  final String level;

  bool get isBundledAsset => storyImage.startsWith('assets/');

  bool isMine(String? uid) => uid != null && uid.isNotEmpty && uid == authorId;

  StoryItem copyWith({bool? hasUnread, List<String>? viewers}) {
    return StoryItem(
      id: id,
      username: username,
      authorId: authorId,
      avatarAsset: avatarAsset,
      avatarUrl: avatarUrl,
      avatarColor: avatarColor,
      avatarText: avatarText,
      hasUnread: hasUnread ?? this.hasUnread,
      storyImage: storyImage,
      time: time,
      createdAt: createdAt,
      caption: caption,
      isVideo: isVideo,
      viewers: viewers ?? this.viewers,
      hiddenFrom: hiddenFrom,
      department: department,
      level: level,
    );
  }
}

/// All of one author's active stories, newest first.
class StoryGroup {
  const StoryGroup({required this.authorId, required this.stories});

  final String authorId;
  final List<StoryItem> stories;

  StoryItem get latest => stories.first;
  bool get hasUnread => stories.any((story) => story.hasUnread);
  String get username => latest.username;
  bool isMine(String? uid) => latest.isMine(uid);
}
