import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../models/direct_chat.dart';
import '../models/story.dart';
import '../services/auth_service.dart';
import '../services/chat_media_cache.dart';
import '../services/chat_store.dart';
import '../services/story_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../utils/active_time.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/story_media.dart';

/// Full-screen story viewer for one author's stories.
///
/// Images advance after six seconds; videos play for their real duration.
/// Tapping the right side advances, the left side goes back, and holding
/// pauses playback. Quick reactions float upward and fade before being sent
/// as a direct message to the author. The signed-in author can see the view
/// count and delete their own story.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<StoryItem> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();

  late int _index;
  VideoPlayerController? _videoController;
  bool _videoLoading = false;
  bool _paused = false;
  bool _deleting = false;
  final List<_StoryReactionBurst> _reactionBursts = [];
  int _nextReactionId = 0;

  static const List<String> _quickReactions = [
    '❤️',
    '😂',
    '🔥',
    '👏',
    '😮',
    '🙏',
  ];

  StoryItem get _story => widget.stories[_index];

  bool get _isMine => _story.isMine(StoryStore.instance.viewerId);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_paused && mounted) {
        _next();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStory(_index));
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    _disposeVideo();
    super.dispose();
  }

  Future<void> _showStory(int index) async {
    if (index < 0) {
      await _restartCurrent();
      return;
    }
    if (index >= widget.stories.length) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    _disposeVideo();
    _progressController.stop();
    _progressController.value = 0;
    setState(() {
      _index = index;
      _videoLoading = _story.isVideo;
      _paused = false;
    });
    _replyController.clear();
    StoryStore.instance.markSeen(_story);

    if (!_story.isVideo) {
      _progressController.duration = const Duration(seconds: 6);
      if (mounted) _progressController.forward(from: 0);
      return;
    }

    final file = _story.isBundledAsset
        ? null
        : await ChatMediaCache.instance.ensureDownloaded(
            _story.storyImage,
            folder: ChatMediaCache.storyFolder,
          );
    if (!mounted) return;
    if (_story.isBundledAsset) {
      _progressController.duration = const Duration(seconds: 6);
      setState(() => _videoLoading = false);
      _progressController.forward(from: 0);
      return;
    }
    if (file == null) {
      _progressController.duration = const Duration(seconds: 6);
      setState(() => _videoLoading = false);
      _progressController.forward(from: 0);
      return;
    }

    final controller = VideoPlayerController.file(file);
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1);
      if (!mounted || _index != index) return;
      final duration = controller.value.duration;
      _progressController.duration = duration.inMilliseconds > 500
          ? duration
          : const Duration(seconds: 6);
      setState(() => _videoLoading = false);
      if (!_paused) {
        await controller.play();
        _progressController.forward(from: 0);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoLoading = false);
      _progressController.duration = const Duration(seconds: 6);
      _progressController.forward(from: 0);
    }
  }

  Future<void> _restartCurrent() async {
    _disposeVideo();
    _progressController.value = 0;
    await _showStory(_index);
  }

  void _next() {
    if (_index + 1 >= widget.stories.length) {
      Navigator.of(context).maybePop();
      return;
    }
    unawaited(_showStory(_index + 1));
  }

  void _previous() {
    if (_index == 0) {
      unawaited(_restartCurrent());
      return;
    }
    unawaited(_showStory(_index - 1));
  }

  void _pause() {
    if (_paused) return;
    setState(() => _paused = true);
    _progressController.stop();
    unawaited(_videoController?.pause());
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _progressController.forward();
    unawaited(_videoController?.play());
  }

  void _disposeVideo() {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) unawaited(controller.dispose());
  }

  void _react(String emoji) {
    final id = _nextReactionId++;
    setState(() {
      if (_reactionBursts.length >= 8) _reactionBursts.removeAt(0);
      _reactionBursts.add(
        _StoryReactionBurst(id: id, emoji: emoji, column: id % 3),
      );
    });
    unawaited(_sendToAuthor(emoji, reaction: true));
  }

  void _removeReaction(int id) {
    if (!mounted) return;
    setState(() {
      _reactionBursts.removeWhere((burst) => burst.id == id);
    });
  }

  Future<void> _sendReply(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final username = _story.username;
    final sent = await _sendToAuthor(trimmed);
    if (!sent || !mounted) return;

    _replyController.clear();
    setState(() {});
    _showStorySnack('Reply sent to $username');
  }

  Future<bool> _sendToAuthor(String message, {bool reaction = false}) async {
    if (_isMine) return false;

    final store = ChatStore.instance;
    final authorId = _story.authorId.trim();
    if (!store.isEnabled || authorId.isEmpty) {
      _showStorySnack(
        reaction
            ? 'Sign in to react to stories.'
            : 'Sign in to reply to stories.',
      );
      return false;
    }

    try {
      var author = ChatUser(
        id: authorId,
        name: _story.username,
        username: _story.username,
        photoUrl: _story.avatarUrl,
        department: _story.department,
        level: _story.level,
      );
      final profile = await AuthService.instance.userProfileFor(authorId);
      if (profile != null && profile.isNotEmpty) {
        author = ChatUser.fromMap(authorId, profile);
      }
      await store.sendText(peer: author, text: message);
      return true;
    } on StateError catch (error) {
      _showStorySnack(error.message);
    } catch (_) {
      _showStorySnack(
        reaction
            ? 'Could not send that reaction. Check your connection.'
            : 'Could not send your reply. Check your connection.',
      );
    }
    return false;
  }

  void _showStorySnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: SpotifyColors.surface,
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _deleteStory() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text(
          'Delete story?',
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
        content: const Text(
          'This story will be removed for everyone.',
          style: TextStyle(fontFamily: AppTheme.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: SpotifyColors.accent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await StoryStore.instance.delete(_story);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError ? error.message : 'Could not delete story.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_story.isVideo) _videoSurface() else _imageSurface(),

          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.2, 0.66, 1.0],
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = MediaQuery.of(context).size.width;
                if (details.localPosition.dx < width * 0.3) {
                  _previous();
                } else {
                  _next();
                }
              },
              onLongPressStart: (_) => _pause(),
              onLongPressEnd: (_) => _resume(),
              child: const SizedBox.expand(),
            ),
          ),

          if (_paused)
            const Center(
              child: Icon(LucideIcons.play, color: Colors.white70, size: 58),
            ),

          if (_videoLoading)
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),

          for (final burst in _reactionBursts)
            Positioned(
              right: 22 + burst.column * 36,
              bottom: bottomPadding + 132,
              child: IgnorePointer(
                child: _FloatingStoryReaction(
                  key: ValueKey('story-reaction-${burst.id}'),
                  emoji: burst.emoji,
                  onFinished: () => _removeReaction(burst.id),
                ),
              ),
            ),

          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: _header(scheme),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 16,
            child: _bottomSection(scheme, bottomPadding),
          ),
        ],
      ),
    );
  }

  Widget _imageSurface() {
    return SizedBox.expand(child: StoryMediaImage(story: _story));
  }

  Widget _videoSurface() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: _videoLoading
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.videoOff,
                      color: Colors.white70,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This video could not be played.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }
    final size = controller.value.size;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width <= 0 ? 1 : size.width,
          height: size.height <= 0 ? 1 : size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.stories.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == widget.stories.length - 1 ? 0 : 4,
                  ),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      final value = i < _index
                          ? 1.0
                          : i > _index
                          ? 0.0
                          : _progressController.value;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            SpotifyColors.accent,
                          ),
                          minHeight: 3,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ChatAvatar(
              avatarAsset: _story.avatarAsset,
              avatarUrl: _story.avatarUrl,
              avatarColor: _story.avatarColor,
              avatarInitials: _story.avatarText,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _story.username,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      ActiveTimestamp(
                        at: _story.createdAt,
                        fallback: _story.time,
                        style: AppType.timestamp(
                          scheme,
                        ).copyWith(color: Colors.white.withValues(alpha: 0.72)),
                      ),
                      if (_isMine) ...[
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const Icon(
                          LucideIcons.eye,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_story.viewers.length}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (_isMine)
              IconButton(
                key: const ValueKey('delete-story-button'),
                tooltip: 'Delete story',
                onPressed: _deleting ? null : _deleteStory,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        LucideIcons.trash2,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bottomSection(ColorScheme scheme, double bottomPadding) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_story.caption != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _story.caption!,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (!_isMine) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickReactions.map((emoji) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => _react(emoji),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: SpotifyColors.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _replyBar(scheme),
        ] else ...[
          Row(
            children: [
              const Icon(LucideIcons.eye, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                '${_story.viewers.length} ${_story.viewers.length == 1 ? 'view' : 'views'}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              Text(
                'Posted by you',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _replyBar(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attachments are not available in stories'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SpotifyColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Icon(LucideIcons.plus, color: scheme.onSurface, size: 24),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: SpotifyColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    maxLines: 4,
                    minLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: scheme.onSurface,
                      fontSize: 15,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: 'Reply to ${_story.username}...',
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: scheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (_replyController.text.trim().isEmpty)
                  IconButton(
                    icon: Icon(
                      LucideIcons.mic,
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                    tooltip: 'Voice message',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hold to record voice message'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  )
                else
                  IconButton(
                    key: const ValueKey('story-send-button'),
                    icon: const Icon(
                      LucideIcons.arrowUp,
                      color: SpotifyColors.accent,
                      size: 22,
                    ),
                    tooltip: 'Send reply',
                    onPressed: () => _sendReply(_replyController.text),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryReactionBurst {
  const _StoryReactionBurst({
    required this.id,
    required this.emoji,
    required this.column,
  });

  final int id;
  final String emoji;
  final int column;
}

/// A single emoji that drifts up the story and fades out.
class _FloatingStoryReaction extends StatefulWidget {
  const _FloatingStoryReaction({
    required this.emoji,
    required this.onFinished,
    super.key,
  });

  final String emoji;
  final VoidCallback onFinished;

  @override
  State<_FloatingStoryReaction> createState() => _FloatingStoryReactionState();
}

class _FloatingStoryReactionState extends State<_FloatingStoryReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: Text(widget.emoji, style: const TextStyle(fontSize: 34)),
      builder: (context, child) {
        final t = _progress.value;
        return Opacity(
          opacity: 1.0 - t,
          child: Transform.translate(
            offset: Offset(math.sin(t * math.pi * 1.4) * 12, -170 * t),
            child: Transform.scale(scale: 1 + 0.35 * t, child: child),
          ),
        );
      },
    );
  }
}
