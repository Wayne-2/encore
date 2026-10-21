import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/trend.dart';
import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../services/trend_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../utils/active_time.dart';
import '../widgets/comment_thread.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/trend_cover.dart';
import '../widgets/user_avatar.dart';
import 'trend_image_viewer_screen.dart';

/// Full-page view of a single trend: its image, title, author, time and body —
/// followed by the same Twitter-style comment thread as announcements.
class TrendingDetailScreen extends StatefulWidget {
  const TrendingDetailScreen({super.key, required this.trend, this.viewerId});

  final Trend trend;

  /// Overrides the signed-in user when resolving delete permission.
  final String? viewerId;

  @override
  State<TrendingDetailScreen> createState() => _TrendingDetailScreenState();
}

class _TrendingDetailScreenState extends State<TrendingDetailScreen> {
  String? get _viewerId =>
      widget.viewerId ??
      (AuthService.isAvailable ? AuthService.instance.currentUser?.uid : null);

  @override
  void initState() {
    super.initState();
    TrendStore.instance.listenToComments(widget.trend.id);
  }

  @override
  void dispose() {
    TrendStore.instance.stopListeningToComments(widget.trend.id);
    super.dispose();
  }

  void _openImages(Trend trend) {
    final images = TrendImageViewerScreen.imagesFrom(trend.media);
    if (images.isEmpty) return;
    Navigator.of(
      context,
    ).push(fadeRoute(TrendImageViewerScreen(media: images)));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Delete trend?'),
        content: const Text('This trend will be removed from the feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('delete-trend-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    TrendStore.instance.delete(widget.trend);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trend = widget.trend;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Trending',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          if (trend.canBeDeletedBy(_viewerId))
            IconButton(
              key: const ValueKey('delete-trend-button'),
              tooltip: 'Delete trend',
              icon: const Icon(LucideIcons.trash2),
              color: scheme.onSurfaceVariant,
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: TrendStore.instance,
        builder: (context, _) => CommentThread(
          header: _TrendHeader(
            trend: trend,
            onMediaTap:
                trend.media.isNotEmpty &&
                    TrendImageViewerScreen.holdsImage(trend.media.first)
                ? () => _openImages(trend)
                : null,
          ),
          comments: TrendStore.instance.commentsFor(trend.id),
          loading: TrendStore.instance.commentsLoading(trend.id),
          reactionsBasePath: 'trends/${trend.id}',
          onSubmit: (text, {replyTo}) =>
              TrendStore.instance.addComment(trend.id, text, replyTo: replyTo),
        ),
      ),
    );
  }
}

/// The trend post shown above its comment thread.
class _TrendHeader extends StatelessWidget {
  const _TrendHeader({required this.trend, this.onMediaTap});

  final Trend trend;
  final VoidCallback? onMediaTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrendCover(
            key: const ValueKey('trend-detail-cover'),
            media: trend.media,
            width: double.infinity,
            height: 190,
            onTap: onMediaTap,
          ),
          const SizedBox(height: 16),
          Text(trend.title, style: AppType.name(scheme)),
          const SizedBox(height: 6),
          Row(
            children: [
              UserAvatar(
                name: trend.author,
                userId: trend.authorId,
                photoUrl: trend.photoUrl,
                size: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trend.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle(scheme),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              ActiveTimestamp(
                at: trend.createdAt,
                fallback: trend.time,
                style: AppType.timestamp(scheme),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(trend.body, style: AppType.body(scheme)),
          const SizedBox(height: 12),
          ReactionBar(reactionsPath: 'trends/${trend.id}'),
        ],
      ),
    );
  }
}
