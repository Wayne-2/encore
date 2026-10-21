import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/trend.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// Square (or fixed-size) cover for a trend's first media item.
///
/// Text-only trends fall back to a subtle accent-tinted placeholder so cards
/// keep the same visual weight as media posts.
class TrendCover extends StatelessWidget {
  const TrendCover({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.onTap,
  });

  final List<TrendMedia> media;
  final double? width;
  final double? height;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = media.isEmpty ? null : media.first;

    Widget placeholder() => DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SpotifyColors.surfaceHover, SpotifyColors.surface],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.trendingUp,
          size: 34,
          color: scheme.primary.withValues(alpha: 0.8),
        ),
      ),
    );

    final coverWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: cover == null
            ? placeholder()
            : Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(cover, placeholder),
                  if (cover.isVideo) ...[
                    const _Scrim(),
                    const Center(child: _PlayBadge()),
                    if (cover.duration > Duration.zero)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Text(
                          _formatDuration(cover.duration),
                          style: AppType.meta(
                            scheme,
                          ).copyWith(color: Colors.white),
                        ),
                      ),
                  ],
                  if (media.length > 1)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.image,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${media.length}',
                              style: AppType.meta(
                                scheme,
                              ).copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );

    final onTap = this.onTap;
    if (onTap == null) return coverWidget;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: coverWidget,
    );
  }

  Widget _buildImage(TrendMedia cover, Widget Function() placeholder) {
    final thumbnail = cover.thumbnail;
    final fallback = thumbnail == null
        ? placeholder()
        : Image.memory(thumbnail, fit: BoxFit.cover, gaplessPlayback: true);

    if (cover.url.isNotEmpty) {
      return Image.network(
        cover.url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return fallback;
        },
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return fallback;
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: const Icon(LucideIcons.play, color: Colors.white, size: 24),
    );
  }
}
