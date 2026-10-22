import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../navigation/app_route.dart';
import '../screens/full_screen_media_viewer.dart';
import '../services/chat_media_cache.dart';

/// Photo attachment that always renders from the on-device media cache.
class ChatMediaImage extends StatefulWidget {
  const ChatMediaImage({
    super.key,
    required this.url,
    this.width = 250,
    this.fit = BoxFit.cover,
    this.heroTag,
  });

  final String url;
  final double width;
  final BoxFit fit;
  final String? heroTag;

  @override
  State<ChatMediaImage> createState() => _ChatMediaImageState();
}

class _ChatMediaImageState extends State<ChatMediaImage> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final file = await ChatMediaCache.instance.ensureDownloaded(
      widget.url,
      folder: ChatMediaCache.imageFolder,
    );
    if (!mounted) return;
    setState(() {
      _file = file;
      _failed = file == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) {
      final image = Hero(
        tag: widget.heroTag ?? widget.url,
        child: Image.file(
          file,
          width: widget.width,
          fit: widget.fit,
          errorBuilder: (_, _, _) => _error(),
        ),
      );
      return GestureDetector(
        key: const ValueKey('chat-media-preview'),
        onTap: () => Navigator.of(context).push(
          fadeRoute(
            FullScreenMediaViewer(
              url: widget.url,
              heroTag: widget.heroTag ?? widget.url,
            ),
          ),
        ),
        child: image,
      );
    }
    if (_failed) return _error();
    return SizedBox(
      width: widget.width,
      height: 160,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
      ),
    );
  }

  Widget _error() {
    return Container(
      width: widget.width,
      height: 160,
      color: Colors.black26,
      child: const Icon(LucideIcons.imageOff, color: Colors.white70),
    );
  }
}
