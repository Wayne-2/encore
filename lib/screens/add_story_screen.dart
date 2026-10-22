import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../services/media_compressor.dart';
import '../services/story_store.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

/// Snapchat-style story composer.
///
/// The camera is the first screen. A tap captures a photo, holding the shutter
/// records a video, and the gallery can supply either. The captured media is
/// then previewed full-bleed with a caption before it is posted to the user's
/// department + level story.
class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocus = FocusNode();

  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  FlashMode _flash = FlashMode.off;
  bool _cameraReady = false;
  bool _cameraFailed = false;
  bool _recording = false;
  bool _posting = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  XFile? _media;
  bool _isVideo = false;
  VideoPlayerController? _videoPreview;
  bool _videoPreviewFailed = false;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_onCaptionChanged);
    unawaited(_initCamera());
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _captionController
      ..removeListener(_onCaptionChanged)
      ..dispose();
    _captionFocus.dispose();
    _videoPreview?.dispose();
    final camera = _camera;
    _camera = null;
    camera?.dispose();
    super.dispose();
  }

  void _onCaptionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initCamera({int? index}) async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _cameraFailed = true);
        return;
      }
      final nextIndex = index ?? _cameraIndex;
      final camera = CameraController(
        _cameras[nextIndex],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await camera.initialize();
      await _applyFlash(camera, _flash);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      final previous = _camera;
      setState(() {
        _camera = camera;
        _cameraIndex = nextIndex;
        _cameraReady = true;
        _cameraFailed = false;
      });
      await previous?.dispose();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraFailed = true;
      });
    }
  }

  Future<void> _applyFlash(CameraController camera, FlashMode mode) async {
    try {
      await camera.setFlashMode(mode);
    } catch (_) {
      // Some front cameras do not expose flash; leave the mode unchanged.
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null || !_cameraReady) return;
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    setState(() => _flash = next);
    await _applyFlash(camera, next);
  }

  IconData get _flashIcon => switch (_flash) {
    FlashMode.auto => LucideIcons.zap,
    FlashMode.always || FlashMode.torch => LucideIcons.zap,
    _ => LucideIcons.zapOff,
  };

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _recording) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    setState(() {
      _cameraReady = false;
      _flash = FlashMode.off;
    });
    await _initCamera(index: next);
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || !_cameraReady || _posting) return;
    try {
      final file = await camera.takePicture();
      if (!mounted) return;
      _setMedia(file, isVideo: false);
    } on CameraException catch (error) {
      _showMessage(error.description ?? 'Could not take that photo.');
    }
  }

  Future<void> _startRecording() async {
    final camera = _camera;
    if (camera == null || !_cameraReady || _recording || _posting) return;
    try {
      await camera.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_recording) return;
        setState(() => _recordSeconds++);
        if (_recordSeconds >= 30) unawaited(_stopRecording());
      });
    } on CameraException catch (error) {
      _showMessage(error.description ?? 'Could not start recording.');
    }
  }

  Future<void> _stopRecording() async {
    final camera = _camera;
    if (camera == null || !_recording) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      final file = await camera.stopVideoRecording();
      if (!mounted) return;
      setState(() => _recording = false);
      _setMedia(file, isVideo: true);
    } on CameraException catch (error) {
      if (mounted) setState(() => _recording = false);
      _showMessage(error.description ?? 'Could not finish that video.');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_posting) return;
    try {
      final file = await ImagePicker().pickMedia(
        maxWidth: 1440,
        maxHeight: 2560,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final extension = file.path.split('.').last.toLowerCase();
      final isVideo = const {
        'mp4',
        'mov',
        'm4v',
        'webm',
        'mkv',
        '3gp',
      }.contains(extension);
      _setMedia(file, isVideo: isVideo);
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Could not open your gallery.');
    }
  }

  void _setMedia(XFile file, {required bool isVideo}) {
    _videoPreview?.dispose();
    _videoPreview = null;
    if (!isVideo) {
      setState(() {
        _media = file;
        _isVideo = false;
      });
      return;
    }

    final controller = VideoPlayerController.file(File(file.path));
    setState(() {
      _media = file;
      _isVideo = true;
      _videoPreview = controller;
      _videoPreviewFailed = false;
    });
    unawaited(_prepareVideo(controller));
  }

  Future<void> _prepareVideo(VideoPlayerController controller) async {
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _videoPreviewFailed = true);
      _showMessage('That video could not be previewed.');
    }
  }

  void _discardMedia() {
    _videoPreview?.dispose();
    _videoPreview = null;
    _captionController.clear();
    _captionFocus.unfocus();
    setState(() {
      _media = null;
      _isVideo = false;
      _videoPreviewFailed = false;
    });
  }

  Future<void> _post() async {
    final media = _media;
    if (media == null || _posting) return;
    setState(() => _posting = true);
    try {
      var path = media.path;
      path = _isVideo
          ? await MediaCompressor.instance.compressStoryVideo(path)
          : await MediaCompressor.instance.compressStoryImage(path);
      await StoryStore.instance.publish(
        filePath: path,
        isVideo: _isVideo,
        caption: _captionController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not post your story. Check your connection.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: SpotifyColors.surface,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (media == null) _cameraSurface() else _mediaPreview(),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.2, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: _topBar(),
          ),
          if (media != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: bottomPadding + 128,
              child: _captionOverlay(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 16,
            child: media == null ? _captureControls() : _reviewControls(),
          ),
          if (_posting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: SpotifyColors.accent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Posting your story…',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final reviewing = _media != null;
    return Row(
      children: [
        _circleButton(
          icon: LucideIcons.x,
          key: const ValueKey('close-story-composer'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        if (reviewing) ...[
          const SizedBox(width: 10),
          _pill(
            icon: LucideIcons.refreshCcw,
            label: 'Retake',
            onTap: _discardMedia,
          ),
        ],
        const Spacer(),
        if (!reviewing) ...[
          _circleButton(
            key: const ValueKey('story-flash'),
            icon: _flashIcon,
            onPressed: _cameraReady ? _toggleFlash : null,
          ),
          const SizedBox(width: 8),
          _circleButton(
            key: const ValueKey('story-switch-camera'),
            icon: LucideIcons.switchCamera,
            onPressed: _cameras.length > 1 ? _switchCamera : null,
          ),
        ] else
          _pill(icon: LucideIcons.users, label: StoryStore.instance.groupLabel),
      ],
    );
  }

  Widget _cameraSurface() {
    final camera = _camera;
    if (camera != null && _cameraReady) {
      final previewSize = camera.value.previewSize;
      final width = previewSize?.height ?? 1;
      final height = previewSize?.width ?? 1;
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: width,
              height: height,
              child: CameraPreview(camera),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF101214),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _cameraFailed ? LucideIcons.cameraOff : LucideIcons.camera,
                size: 46,
                color: Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 14),
              Text(
                _cameraFailed ? 'Camera unavailable' : 'Starting camera…',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              if (_cameraFailed) ...[
                const SizedBox(height: 6),
                Text(
                  'Choose a photo or video from your gallery instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaPreview() {
    if (_isVideo) {
      final controller = _videoPreview;
      if (controller == null || !controller.value.isInitialized) {
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: _videoPreviewFailed
                ? const Icon(
                    LucideIcons.videoOff,
                    color: Colors.white70,
                    size: 40,
                  )
                : const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
          ),
        );
      }
      final size = controller.value.size;
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: math.max(size.width, 1),
            height: math.max(size.height, 1),
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    final file = File(_media!.path);
    return Image.file(file, fit: BoxFit.cover);
  }

  Widget _captionOverlay() {
    return TextField(
      controller: _captionController,
      focusNode: _captionFocus,
      maxLength: 150,
      maxLines: 3,
      minLines: 1,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        shadows: [
          Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      cursorColor: SpotifyColors.accent,
      decoration: InputDecoration(
        counterText: '',
        border: InputBorder.none,
        hintText: 'Add a caption…',
        hintStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.45),
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }

  Widget _captureControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_recording)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'REC  0:${_recordSeconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _circleButton(
              key: const ValueKey('story-gallery'),
              icon: LucideIcons.images,
              size: 48,
              onPressed: _posting ? null : _pickFromGallery,
            ),
            GestureDetector(
              key: const ValueKey('story-shutter'),
              onTap: _recording ? null : _takePhoto,
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                ),
                padding: const EdgeInsets.all(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: _recording ? Colors.red : Colors.white,
                    shape: _recording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: _recording ? BorderRadius.circular(10) : null,
                  ),
                ),
              ),
            ),
            _circleButton(
              key: const ValueKey('story-camera-toggle'),
              icon: LucideIcons.switchCamera,
              size: 48,
              onPressed: _cameras.length > 1 ? _switchCamera : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _recording ? 'Release to finish' : 'Tap for photo · Hold for video',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _reviewControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _circleButton(
            key: const ValueKey('story-caption-button'),
            icon: LucideIcons.type,
            size: 48,
            onPressed: () => _captionFocus.requestFocus(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.clock3,
                    size: 17,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visible for 24 hours',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            height: 48,
            child: FilledButton(
              key: const ValueKey('post-story-button'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: SpotifyColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _posting ? null : _post,
              child: const Icon(
                LucideIcons.arrowUp,
                color: Colors.black,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Key? key,
    double size = 42,
  }) {
    return Material(
      key: key,
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.48,
            color: onPressed == null
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
