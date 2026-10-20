import 'package:flutter/material.dart';

import '../models/trend.dart';
import '../navigation/app_route.dart';
import '../services/trend_store.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/floating_empty_state.dart';
import '../widgets/trend_cover.dart';
import 'trending_detail_screen.dart';

/// Medium-style "For you" feed showing every posted trend.
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
        title: Text('For you', style: AppType.name(scheme)),
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
                icon: Icons.auto_awesome_outlined,
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
            itemBuilder: (context, i) => _ForYouCard(
              key: ValueKey('trend-feed-$i'),
              trend: trends[i],
              onTap: () => _openTrend(trends[i]),
            ),
          );
        },
      ),
    );
  }
}

/// A single Medium-style story card: author, headline, excerpt and cover.
class _ForYouCard extends StatelessWidget {
  const _ForYouCard({super.key, required this.trend, required this.onTap});

  final Trend trend;
  final VoidCallback onTap;

  static String _initialsFor(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

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
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _initialsFor(author),
                    style: AppType.tag(scheme.primary).copyWith(fontSize: 12),
                  ),
                ),
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
                      Text(
                        trend.time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.meta(scheme),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 17,
                  color: scheme.onSurfaceVariant,
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
                media: trend.media,
                width: double.infinity,
                height: 190,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Read story',
                  style: AppType.tag(scheme.primary).copyWith(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: scheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
