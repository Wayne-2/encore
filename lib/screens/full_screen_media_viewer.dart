import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/chat_media_cache.dart';

/// Full-screen, zoomable view of a photo posted in a chat.
class FullScreenMediaViewer extends StatefulWidget {
  const FullScreenMediaViewer({
    super.key,
    required this.url,
    this.heroTag,
    this.folder = ChatMediaCache.imageFolder,
  });

  final String url;
  final String? heroTag;
  final String folder;

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
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
      folder: widget.folder,
    );
    if (!mounted) return;
    setState(() {
      _file = file;
      _failed = file == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final file = _file;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: file == null
                ? Center(
                    child: _failed
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.imageOff,
                                color: Colors.white70,
                                size: 36,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'This photo could not be loaded.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                  )
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Hero(
                        tag: widget.heroTag ?? widget.url,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            LucideIcons.imageOff,
                            color: Colors.white70,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: topPadding + 8,
            right: 8,
            child: IconButton(
              key: const ValueKey('close-media-viewer'),
              tooltip: 'Close',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.x, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
