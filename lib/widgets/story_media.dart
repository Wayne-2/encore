import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/story.dart';
import '../services/chat_media_cache.dart';

/// Story photo that prefers the on-device cache and supports bundled demos.
class StoryMediaImage extends StatefulWidget {
  const StoryMediaImage({
    super.key,
    required this.story,
    this.fit = BoxFit.cover,
  });

  final StoryItem story;
  final BoxFit fit;

  @override
  State<StoryMediaImage> createState() => _StoryMediaImageState();
}

class _StoryMediaImageState extends State<StoryMediaImage> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.story.isBundledAsset) return;
    final file = await ChatMediaCache.instance.ensureDownloaded(
      widget.story.storyImage,
      folder: ChatMediaCache.storyFolder,
    );
    if (!mounted) return;
    setState(() {
      _file = file;
      _failed = file == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.story.isBundledAsset) {
      return Image.asset(
        widget.story.storyImage,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _error(),
      );
    }
    final file = _file;
    if (file != null) {
      return Image.file(
        file,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _error(),
      );
    }
    if (_failed) return _error();
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
    );
  }

  Widget _error() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Icon(LucideIcons.imageOff, color: Colors.white70, size: 36),
      ),
    );
  }
}
