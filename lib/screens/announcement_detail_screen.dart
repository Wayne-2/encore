import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/comment.dart';
import '../services/announcement_store.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/announcement_tile.dart';
import '../widgets/comment_thread.dart';
import '../widgets/reaction_bar.dart';

/// Full-page view of a single announcement: sender, time, priority and the
/// complete message — followed by a Twitter-style comment thread.
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
    this.viewerId,
  });

  final Announcement announcement;

  /// Overrides the signed-in user when resolving delete permission.
  final String? viewerId;

  static const List<Comment> _comments = [
    Comment(
      name: 'Ama Boateng',
      handle: '_ama_boateng',
      time: '2h',
      text:
          'Thanks for the heads up! Will the lab report template be shared '
          'too?',
      initials: 'AB',
      reactions: {'👍': 4, '🙌': 1},
    ),
    Comment(
      name: 'Kwame Mensah',
      handle: '_kwame_m',
      time: '1h',
      text: 'Noted, submitting mine tonight.',
      initials: 'KM',
      reactions: {'🎉': 2},
    ),
    Comment(
      name: 'Efua Owusu',
      handle: '_efua.o',
      time: '45m',
      text: 'Could we get a short extension? Some of us have labs that day.',
      initials: 'EO',
    ),
  ];

  String? get _viewer =>
      viewerId ??
      (AuthService.isAvailable ? AuthService.instance.currentUser?.uid : null);

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Delete announcement?'),
        content: const Text('This announcement will be removed from the feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    AnnouncementStore.instance.delete(announcement);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Announcement',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          if (announcement.canBeDeletedBy(_viewer))
            IconButton(
              tooltip: 'Delete announcement',
              icon: const Icon(Icons.delete_outline),
              color: scheme.onSurfaceVariant,
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: CommentThread(
        header: _AnnouncementHeader(announcement: announcement),
        initialComments: _comments,
      ),
    );
  }
}

/// The announcement post shown above its comment thread.
class _AnnouncementHeader extends StatelessWidget {
  const _AnnouncementHeader({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnnouncementAvatar(photoUrl: announcement.photoUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(announcement.author, style: SlackType.sender(scheme)),
                    const SizedBox(height: 2),
                    Text(announcement.time, style: SlackType.timestamp(scheme)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(announcement.tag, style: AppType.tag(announcement.tagColor)),
          const SizedBox(height: 12),
          Text(announcement.body, style: SlackType.body(scheme)),
          const SizedBox(height: 12),
          const ReactionBar(initial: {'👍': 8, '🎉': 2}),
        ],
      ),
    );
  }
}
