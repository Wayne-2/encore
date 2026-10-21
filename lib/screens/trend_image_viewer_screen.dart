import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/trend.dart';
import '../theme/app_theme.dart';

/// Full-screen, zoomable gallery for a trend's images.
class TrendImageViewerScreen extends StatefulWidget {
  const TrendImageViewerScreen({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  final List<TrendMedia> media;
  final int initialIndex;

  /// Whether [media] can be opened in the full-screen image viewer.
  static bool holdsImage(TrendMedia media) {
    return !media.isVideo && (media.thumbnail != null || media.url.isNotEmpty);
  }

  /// The viewable images in [media], preserving their order.
  static List<TrendMedia> imagesFrom(List<TrendMedia> media) {
    return media.where(holdsImage).toList(growable: false);
  }

  @override
  State<TrendImageViewerScreen> createState() => _TrendImageViewerScreenState();
}

class _TrendImageViewerScreenState extends State<TrendImageViewerScreen> {
  late final List<TrendMedia> _images = TrendImageViewerScreen.imagesFrom(
    widget.media,
  );
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex
        .clamp(0, _images.isEmpty ? 0 : _images.length - 1)
        .toInt(),
  );
  late int _index = _pageController.initialPage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_images.isEmpty)
            const Center(
              child: Icon(LucideIcons.imageOff, color: Colors.white54),
            )
          else
            PageView.builder(
              key: const ValueKey('trend-image-viewer-pages'),
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => InteractiveViewer(
                key: ValueKey('trend-image-zoom-$index'),
                minScale: 0.8,
                maxScale: 5,
                child: SizedBox.expand(
                  child: _FullTrendImage(media: _images[index]),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  key: const ValueKey('trend-image-viewer-close'),
                  tooltip: 'Close image',
                  icon: const Icon(LucideIcons.x),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
          if (_images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1} / ${_images.length}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The image itself, using its uploaded URL when available and the local
/// thumbnail as the instant/error fallback.
class _FullTrendImage extends StatelessWidget {
  const _FullTrendImage({required this.media});

  final TrendMedia media;

  @override
  Widget build(BuildContext context) {
    final thumbnail = media.thumbnail;
    final url = media.url.trim();

    if (url.isEmpty) {
      return thumbnail == null
          ? const Center(
              child: Icon(
                LucideIcons.imageOff,
                color: Colors.white54,
                size: 36,
              ),
            )
          : Image.memory(thumbnail, fit: BoxFit.contain, gaplessPlayback: true);
    }

    final network = Image.network(
      url,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        if (thumbnail != null) return const SizedBox.shrink();
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) {
        if (thumbnail != null) return const SizedBox.shrink();
        return const Center(
          child: Icon(LucideIcons.imageOff, color: Colors.white54, size: 36),
        );
      },
    );

    if (thumbnail == null) return network;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(thumbnail, fit: BoxFit.contain, gaplessPlayback: true),
        network,
      ],
    );
  }
}
