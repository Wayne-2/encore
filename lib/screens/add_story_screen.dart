import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../models/contact_request.dart';
import '../services/contact_store.dart';
import '../services/media_compressor.dart';
import '../services/story_store.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import '../widgets/user_avatar.dart';

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
  final Set<String> _hiddenFrom = {};

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
        hiddenFrom: {for (final uid in _hiddenFrom) uid},
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
              left: 12,
              right: 12,
              bottom:
                  math.max(
                    MediaQuery.viewInsetsOf(context).bottom,
                    bottomPadding,
                  ) +
                  8,
              child: _reviewComposer(),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding + 16,
              child: _captureControls(),
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
                          fontSize: 15,
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
          _pill(
            key: const ValueKey('story-audience'),
            icon: LucideIcons.users,
            label: _hiddenFrom.isEmpty
                ? 'All contacts'
                : '${_hiddenFrom.length} hidden',
            onTap: _chooseAudience,
          ),
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
                  fontSize: 15,
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
                    fontSize: 12,
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

  Widget _captionField() {
    return TextField(
      controller: _captionController,
      focusNode: _captionFocus,
      maxLength: 150,
      maxLines: 4,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _post(),
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w400,
        color: Colors.white,
        shadows: [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
        ],
      ),
      cursorColor: SpotifyColors.accent,
      decoration: InputDecoration(
        counterText: '',
        border: InputBorder.none,
        hintText: 'Add a caption…',
        hintStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.45),
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _reviewComposer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Opacity(opacity: 0.7, child: _captionField())),
              IconButton(
                key: const ValueKey('post-story-button'),
                tooltip: 'Post story',
                onPressed: _posting ? null : _post,
                icon: const Icon(
                  LucideIcons.arrowUp,
                  color: SpotifyColors.accent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _composerAction(
              key: const ValueKey('story-sticker-button'),
              icon: LucideIcons.sticker,
              tooltip: 'Add sticker',
              onTap: () => _showMessage('Sticker overlays are coming soon.'),
            ),
            const SizedBox(width: 8),
            _composerAction(
              key: const ValueKey('story-visibility-button'),
              icon: LucideIcons.eye,
              tooltip: 'Story visibility',
              onTap: _chooseAudience,
            ),
            const SizedBox(width: 8),
            _composerAction(
              key: const ValueKey('story-crop-button'),
              icon: LucideIcons.crop,
              tooltip: 'Crop media',
              onTap: () => _showMessage('Cropping is coming soon.'),
            ),
            const SizedBox(width: 8),
            _composerAction(
              key: const ValueKey('story-music-button'),
              icon: LucideIcons.music,
              tooltip: 'Add music',
              onTap: () => _showMessage('Music is coming soon.'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _composerAction({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        key: key,
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
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

  Future<void> _chooseAudience() async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StoryAudienceSheet(initial: {..._hiddenFrom}),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _hiddenFrom
        ..clear()
        ..addAll(selected);
    });
  }

  Widget _pill({
    Key? key,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      key: key,
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

class _StoryAudienceSheet extends StatefulWidget {
  const _StoryAudienceSheet({required this.initial});

  final Set<String> initial;

  @override
  State<_StoryAudienceSheet> createState() => _StoryAudienceSheetState();
}

class _StoryAudienceSheetState extends State<_StoryAudienceSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: SpotifyColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Hide story from',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('story-audience-done'),
                    onPressed: () => Navigator.of(context).pop({..._selected}),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selected contacts will not see this story.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<ContactDirectory>(
                stream: ContactStore.instance.watchDirectory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: SpotifyColors.accent,
                      ),
                    );
                  }
                  final entries =
                      (snapshot.data?.entries ?? const <ContactEntry>[])
                          .where(
                            (entry) =>
                                entry.relation == ContactRelation.connected,
                          )
                          .toList();
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        'No contacts yet',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final user = entries[index].user;
                      final hidden = _selected.contains(user.id);
                      return CheckboxListTile(
                        key: ValueKey('story-audience-${user.id}'),
                        value: hidden,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(user.id);
                            } else {
                              _selected.remove(user.id);
                            }
                          });
                        },
                        activeColor: SpotifyColors.accent,
                        checkColor: Colors.black,
                        side: BorderSide(color: scheme.outlineVariant),
                        secondary: UserAvatar(
                          name: user.displayName,
                          photoUrl: user.photoUrl,
                          size: 38,
                        ),
                        title: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          user.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
