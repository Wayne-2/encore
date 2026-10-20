import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/trend.dart';
import '../theme/app_spacing.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

const int _maxSelection = 10;
const int _pageSize = 60;
const ThumbnailSize _thumbnailSize = ThumbnailSize.square(600);

/// The title, body and media picked in the trend composer.
class TrendDraft {
  const TrendDraft({
    required this.title,
    required this.body,
    required this.media,
  });

  final String title;
  final String body;
  final List<TrendMedia> media;
}

/// Opens the themed sheet for posting a trend.
///
/// Completes with the draft once the user taps Post, or `null` when dismissed.
Future<TrendDraft?> showComposeTrendSheet(BuildContext context) {
  return showModalBottomSheet<TrendDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SpotifyColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => const ComposeTrendSheet(),
  );
}

/// Composer with a title, body and a three-column grid of the device gallery.
class ComposeTrendSheet extends StatefulWidget {
  const ComposeTrendSheet({super.key});

  @override
  State<ComposeTrendSheet> createState() => _ComposeTrendSheetState();
}

class _ComposeTrendSheetState extends State<ComposeTrendSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final Map<String, Future<Uint8List?>> _thumbnails = {};
  final Map<String, AssetEntity> _selected = {};

  AssetPathEntity? _album;
  List<AssetEntity> _assets = const [];
  bool _unsupported = false;
  bool _loadingGallery = true;
  bool _permissionDenied = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _posting = false;
  int _page = 0;

  bool get _gallerySupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _canPost =>
      !_posting &&
      _title.text.trim().isNotEmpty &&
      _body.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_gallerySupported) {
      _loadGallery();
    } else {
      _unsupported = true;
      _loadingGallery = false;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    setState(() {
      _loadingGallery = true;
      _permissionDenied = false;
    });

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!mounted) return;
      if (!permission.hasAccess) {
        setState(() {
          _loadingGallery = false;
          _permissionDenied = true;
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: const [
            OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (!mounted) return;
      if (albums.isEmpty) {
        setState(() {
          _loadingGallery = false;
          _hasMore = false;
        });
        return;
      }

      final album = albums.first;
      final assets = await album.getAssetListPaged(page: 0, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _album = album;
        _assets = assets;
        _page = 1;
        _hasMore = assets.length == _pageSize;
        _loadingGallery = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGallery = false;
        _permissionDenied = true;
      });
    }
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final assets = await album.getAssetListPaged(
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _assets = [..._assets, ...assets];
        _page++;
        _hasMore = assets.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 600) _loadMore();
    return false;
  }

  Future<Uint8List?> _thumbnail(AssetEntity asset) {
    return _thumbnails.putIfAbsent(
      asset.id,
      () => asset.thumbnailDataWithSize(_thumbnailSize),
    );
  }

  void _toggle(AssetEntity asset) {
    if (_selected.containsKey(asset.id)) {
      setState(() => _selected.remove(asset.id));
      return;
    }

    if (_selected.length >= _maxSelection) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('You can attach up to $_maxSelection items.'),
          ),
        );
      return;
    }

    setState(() => _selected[asset.id] = asset);
  }

  Future<void> _post() async {
    if (!_canPost) return;
    setState(() => _posting = true);

    final media = <TrendMedia>[];
    for (final asset in _selected.values) {
      final bytes = await _thumbnail(asset);
      if (bytes == null) continue;
      media.add(
        TrendMedia(
          thumbnail: bytes,
          isVideo: asset.type == AssetType.video,
          duration: Duration(seconds: asset.duration),
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      TrendDraft(
        title: _title.text.trim(),
        body: _body.text.trim(),
        media: media,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final keyboard = mediaQuery.viewInsets.bottom;
    final maxHeight = mediaQuery.size.height * 0.9;
    final height = (maxHeight - keyboard).clamp(300.0, maxHeight);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([_title, _body]),
                builder: (context, _) => _SheetHeader(
                  canPost: _canPost,
                  posting: _posting,
                  onPost: _post,
                ),
              ),
              const Divider(height: 1, color: SpotifyColors.border),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ComposeFields(title: _title, body: _body),
                      ),
                      SliverToBoxAdapter(
                        child: _GalleryHeading(
                          count: _selected.length,
                          scheme: scheme,
                        ),
                      ),
                      ..._gallerySlivers(scheme),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.section),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _gallerySlivers(ColorScheme scheme) {
    if (_loadingGallery) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ];
    }

    if (_unsupported) {
      return [
        SliverToBoxAdapter(
          child: _GalleryMessage(
            icon: Icons.photo_library_outlined,
            text: 'Your gallery isn’t available on this device.',
            scheme: scheme,
          ),
        ),
      ];
    }

    if (_permissionDenied) {
      return [
        SliverToBoxAdapter(
          child: _GalleryMessage(
            icon: Icons.lock_outline,
            text:
                'Allow access to your photos and videos to attach them to '
                'your trend.',
            scheme: scheme,
            action: TextButton(
              onPressed: _loadGallery,
              child: const Text('Allow access'),
            ),
          ),
        ),
      ];
    }

    if (_assets.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _GalleryMessage(
            icon: Icons.photo_library_outlined,
            text: 'No photos or videos found.',
            scheme: scheme,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final asset = _assets[index];
            return _GalleryTile(
              key: ValueKey('trend-gallery-${asset.id}'),
              asset: asset,
              thumbnail: _thumbnail(asset),
              selected: _selected.containsKey(asset.id),
              onTap: () => _toggle(asset),
            );
          }, childCount: _assets.length),
        ),
      ),
      if (_loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
    ];
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.canPost,
    required this.posting,
    required this.onPost,
  });

  final bool canPost;
  final bool posting;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SpotifyColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Post Trend',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sectionTitle(scheme),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                child: FilledButton(
                  key: const ValueKey('post-trend-button'),
                  onPressed: canPost ? onPost : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: SpotifyColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: SpotifyColors.surfaceHover,
                    disabledForegroundColor: SpotifyColors.textSubdued,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: posting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposeFields extends StatelessWidget {
  const _ComposeFields({required this.title, required this.body});

  final TextEditingController title;
  final TextEditingController body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('trend-title'),
            controller: title,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: AppType.sectionTitle(
              scheme,
            ).copyWith(fontSize: 20, height: 1.2),
            decoration: InputDecoration(
              hintText: 'Title',
              hintStyle: AppType.sectionTitle(
                scheme,
              ).copyWith(fontSize: 20, color: SpotifyColors.textSubdued),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: SpotifyColors.border),
          TextField(
            key: const ValueKey('trend-body'),
            controller: body,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: AppType.body(scheme).copyWith(color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: 'What’s happening?',
              hintStyle: AppType.body(scheme),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryHeading extends StatelessWidget {
  const _GalleryHeading({required this.count, required this.scheme});

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Text('Gallery', style: AppType.cardTitle(scheme)),
          const SizedBox(width: 8),
          if (count > 0)
            Text(
              '$count selected',
              style: AppType.meta(scheme).copyWith(color: scheme.primary),
            ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    super.key,
    required this.asset,
    required this.thumbnail,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity asset;
  final Future<Uint8List?> thumbnail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: thumbnail,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return const ColoredBox(color: SpotifyColors.surfaceHover);
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
          if (asset.type == AssetType.video)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam, size: 11, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      _formatDuration(asset.duration),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (selected)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: SpotifyColors.accent, width: 3),
                color: Colors.black.withValues(alpha: 0.22),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? SpotifyColors.accent
                    : Colors.black.withValues(alpha: 0.4),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage({
    required this.icon,
    required this.text,
    required this.scheme,
    this.action,
  });

  final IconData icon;
  final String text;
  final ColorScheme scheme;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 22),
      child: Column(
        children: [
          Icon(icon, size: 30, color: SpotifyColors.textSubdued),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppType.subtitle(scheme),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
