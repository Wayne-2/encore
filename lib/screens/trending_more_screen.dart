import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/trend.dart';
import '../navigation/app_route.dart';
import '../services/trend_store.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../utils/active_time.dart';
import '../widgets/floating_empty_state.dart';
import '../widgets/trend_cover.dart';
import '../widgets/user_avatar.dart';
import 'trend_image_viewer_screen.dart';
import 'trending_detail_screen.dart';

/// Medium-style "All trending topics" feed showing every posted trend.
///
/// Each story opens the full [TrendingDetailScreen], including its comment
/// thread and reactions.
class TrendingMoreScreen extends StatefulWidget {
  const TrendingMoreScreen({super.key, this.viewerId});

  /// Overrides the signed-in user when resolving delete permission.
  final String? viewerId;

  @override
  State<TrendingMoreScreen> createState() => _TrendingMoreScreenState();
}

class _TrendingMoreScreenState extends State<TrendingMoreScreen> {
  @override
  void initState() {
    super.initState();
    TrendStore.instance.listen();
  }

  void _openTrend(Trend trend) {
    Navigator.of(context).push(
      sharedAxisRoute(
        TrendingDetailScreen(trend: trend, viewerId: widget.viewerId),
      ),
    );
  }

  void _openImages(Trend trend) {
    final images = TrendImageViewerScreen.imagesFrom(trend.media);
    if (images.isEmpty) return;
    Navigator.of(
      context,
    ).push(fadeRoute(TrendImageViewerScreen(media: images)));
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
          icon: const Icon(LucideIcons.chevronLeft),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('All trending topics', style: AppType.name(scheme)),
        centerTitle: false,
      ),
      body: AnimatedBuilder(
        animation: TrendStore.instance,
        builder: (context, _) {
          final trends = TrendStore.instance.items;
          if (trends.isEmpty) {
            return const Center(
              child: FloatingEmptyState(
                key: ValueKey('trend-feed-empty'),
                icon: LucideIcons.trendingUp,
                message: 'No trending stories yet',
              ),
            );
          }

          return ListView.separated(
            key: const ValueKey('trend-feed-list'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: trends.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 1,
              color: SpotifyColors.border,
            ),
            itemBuilder: (context, i) {
              final trend = trends[i];
              final first = trend.media.isEmpty ? null : trend.media.first;
              return _ForYouCard(
                key: ValueKey('trend-feed-$i'),
                coverKey: ValueKey('trend-feed-cover-$i'),
                trend: trend,
                onTap: () => _openTrend(trend),
                onCoverTap:
                    first != null && TrendImageViewerScreen.holdsImage(first)
                    ? () => _openImages(trend)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

/// A single Medium-style story card: author, headline, excerpt and cover.
class _ForYouCard extends StatelessWidget {
  const _ForYouCard({
    super.key,
    required this.trend,
    required this.onTap,
    this.coverKey,
    this.onCoverTap,
  });

  final Trend trend;
  final VoidCallback onTap;
  final Key? coverKey;
  final VoidCallback? onCoverTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = trend.author.trim().isEmpty ? 'Unknown' : trend.author;
    final preview = trend.subtitle.trim().isEmpty
        ? trend.body.trim()
        : trend.subtitle.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(name: author, photoUrl: trend.photoUrl, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.cardTitle(scheme),
                      ),
                      const SizedBox(height: 2),
                      ActiveTimestamp(
                        at: trend.createdAt,
                        fallback: trend.time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.meta(scheme),
                      ),
                    ],
                  ),
                ),
                Text(
                  'View info',
                  style: AppType.tag(scheme.primary).copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              trend.title,
              style: AppType.sectionTitle(
                scheme,
              ).copyWith(fontSize: 22, height: 1.18),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(scheme).copyWith(height: 1.45),
              ),
            ],
            if (trend.media.isNotEmpty) ...[
              const SizedBox(height: 14),
              TrendCover(
                key: coverKey,
                media: trend.media,
                width: double.infinity,
                height: 190,
                onTap: onCoverTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
