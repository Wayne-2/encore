import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/local_cache.dart';

/// A profile photo that renders Hive-cached bytes first, then refreshes them
/// from the network whenever [url] changes.
///
/// The parent profile stores and streams already emit the Hive-cached URL
/// before Firestore replies. This widget closes the loop by caching the bytes
/// behind that URL, so avatars survive restarts and offline launches.
class CachedProfileImage extends StatefulWidget {
  const CachedProfileImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.fallback,
    this.alignment = Alignment.center,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? fallback;
  final Alignment alignment;

  @override
  State<CachedProfileImage> createState() => _CachedProfileImageState();
}

class _CachedProfileImageState extends State<CachedProfileImage> {
  Uint8List? _bytes;
  String? _bytesUrl;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load(widget.url);
  }

  @override
  void didUpdateWidget(CachedProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load(widget.url);
  }

  void _load(String url) {
    final request = ++_request;
    if (url.isEmpty) {
      _bytes = null;
      _bytesUrl = null;
      return;
    }

    final cached = LocalCache.instance.imageBytes(url);
    if (cached != null && cached.isNotEmpty) {
      _bytes = cached;
      _bytesUrl = url;
      return;
    }

    _bytes = null;
    _bytesUrl = null;
    unawaited(_download(url, request));
  }

  Future<void> _download(String url, int request) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (!mounted || request != _request) return;
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return;

      await LocalCache.instance.saveImageBytes(url, response.bodyBytes);
      if (!mounted || request != _request) return;
      setState(() {
        _bytes = response.bodyBytes;
        _bytesUrl = url;
      });
    } catch (_) {
      // Keep the fallback; a later rebuild or URL change can retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final showImage = bytes != null && _bytesUrl == widget.url;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = _targetPixels(widget.width, dpr);
    final cacheHeight = _targetPixels(widget.height, dpr);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: showImage
          ? Image.memory(
              bytes,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              alignment: widget.alignment,
              filterQuality: widget.filterQuality,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  widget.fallback ?? const SizedBox.shrink(),
            )
          : (widget.fallback ?? const SizedBox.shrink()),
    );
  }

  static int? _targetPixels(double? size, double dpr) {
    if (size == null || !size.isFinite || size <= 0) return null;
    return (size * dpr).round();
  }
}
