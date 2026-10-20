import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/announcement_store.dart';
import '../services/auth_service.dart';
import '../services/comment_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/slack_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/announcement_tile.dart';
import '../widgets/comment_thread.dart';
import '../widgets/reaction_bar.dart';

/// Full-page view of a single announcement: sender, time, priority and the
/// complete message — followed by a Twitter-style comment thread.
class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.announcement,
    this.viewerId,
  });

  final Announcement announcement;

  /// Overrides the signed-in user when resolving delete permission.
  final String? viewerId;

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  late final String _postId = widget.announcement.id.isNotEmpty
      ? widget.announcement.id
      : 'local-${identityHashCode(widget.announcement)}';

  String? get _viewer =>
      widget.viewerId ??
      (AuthService.isAvailable ? AuthService.instance.currentUser?.uid : null);

  String? get _reactionsPath => widget.announcement.id.isEmpty
      ? null
      : 'announcements/${widget.announcement.id}';

  @override
  void initState() {
    super.initState();
    CommentStore.instance.listen(_postId);
  }

  @override
  void dispose() {
    CommentStore.instance.stopListening(_postId);
    super.dispose();
  }

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
    AnnouncementStore.instance.delete(widget.announcement);
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
          if (widget.announcement.canBeDeletedBy(_viewer))
            IconButton(
              tooltip: 'Delete announcement',
              icon: const Icon(Icons.delete_outline),
              color: scheme.onSurfaceVariant,
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: CommentStore.instance,
        builder: (context, _) => CommentThread(
          header: _AnnouncementHeader(
            announcement: widget.announcement,
            reactionsPath: _reactionsPath,
          ),
          comments: CommentStore.instance.commentsFor(_postId),
          loading: CommentStore.instance.isLoading(_postId),
          reactionsBasePath: _reactionsPath,
          onSubmit: (text) => CommentStore.instance.add(_postId, text),
        ),
      ),
    );
  }
}

/// The announcement post shown above its comment thread.
class _AnnouncementHeader extends StatelessWidget {
  const _AnnouncementHeader({required this.announcement, this.reactionsPath});

  final Announcement announcement;
  final String? reactionsPath;

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
          ReactionBar(reactionsPath: reactionsPath),
        ],
      ),
    );
  }
}
