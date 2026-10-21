import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image/image.dart' as img;

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';

/// The largest edge the cropper has to parse.
///
/// [Crop] decodes the whole image with a pure-Dart decoder before it can show
/// the editor. Camera photos can be many megapixels, which takes seconds on a
/// phone, so downscale with Flutter's native codec first. 960px is still sharp
/// enough for both the profile hero and the avatar.
const int _maxCropEdge = 960;

bool _isPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

/// Encodes native RGBA pixels as JPEG on a background isolate.
Uint8List _encodeJpeg(
  ({int width, int height, int offset, Uint8List rgba}) input,
) {
  final image = img.Image.fromBytes(
    width: input.width,
    height: input.height,
    bytes: input.rgba.buffer,
    bytesOffset: input.offset,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 88);
}

/// Downsizes [bytes] with the engine's native decoder before the cropper
/// parses it. Falls back to the original bytes on unsupported formats.
Future<Uint8List> _prepareForCrop(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longestEdge = math.max(descriptor.width, descriptor.height);
    if (longestEdge <= _maxCropEdge) return bytes;

    final scale = _maxCropEdge / longestEdge;
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round(),
      targetHeight: (descriptor.height * scale).round(),
    );
    final frame = await codec.getNextFrame();
    image = frame.image;

    if (_isPng(bytes)) {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data == null
          ? bytes
          : data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }

    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return bytes;
    return compute(_encodeJpeg, (
      width: image.width,
      height: image.height,
      offset: data.offsetInBytes,
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ));
  } catch (_) {
    return bytes;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Square, 4px-rounded crop step for a picked profile photo.
///
/// Pops with the cropped [Uint8List] when the user confirms, or `null` when
/// they back out.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({super.key, required this.image});

  final Uint8List image;

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();
  Uint8List? _image;
  bool _cropping = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final prepared = await _prepareForCrop(widget.image);
    if (!mounted) return;
    setState(() => _image = prepared);
  }

  void _crop() {
    if (_image == null) return;
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
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Crop photo', style: AppType.name(scheme)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _image == null
                ? const Center(child: AppLoader())
                : Crop(
                    image: _image!,
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
