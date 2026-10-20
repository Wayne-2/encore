import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';

/// Square, 4px-rounded crop step for a picked profile photo.
///
/// Pops with the cropped [Uint8List] (original format) when the user confirms,
/// or `null` when they back out.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({super.key, required this.image});

  final Uint8List image;

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();
  bool _cropping = false;
  bool _failed = false;

  void _crop() {
    setState(() {
      _cropping = true;
      _failed = false;
    });
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Crop photo', style: AppType.name(scheme)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _controller,
              aspectRatio: 1,
              interactive: true,
              baseColor: SpotifyColors.background,
              maskColor: Colors.black.withValues(alpha: 0.55),
              radius: 4,
              progressIndicator: const Center(child: AppLoader()),
              onCropped: (result) {
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    if (!mounted) return;
                    Navigator.of(context).pop(croppedImage);
                  case CropFailure():
                    if (!mounted) return;
                    setState(() {
                      _cropping = false;
                      _failed = true;
                    });
                }
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_failed) ...[
                    Text(
                      'Couldn’t crop that photo. Try another one.',
                      textAlign: TextAlign.center,
                      style: AppType.subtitle(
                        scheme,
                      ).copyWith(color: SpotifyColors.danger),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _cropping ? null : _crop,
                      child: _cropping
                          ? const AppLoader(size: 16)
                          : const Text('Use photo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
