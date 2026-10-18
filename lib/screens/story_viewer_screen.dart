import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import '../widgets/chat_avatar.dart';

/// Full-screen WhatsApp-style story/status viewer for stories tapped in `# Story`.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({super.key, required this.story});

  final StoryItem story;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();

  static const List<String> _quickReactions = [
    '❤️',
    '😂',
    '🔥',
    '👏',
    '😮',
    '🙏',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _sendReply(String text) {
    if (text.trim().isEmpty) return;
    _replyController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SpotifyColors.surface,
        content: Text(
          'Reply sent to ${widget.story.username}',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: Colors.white,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
        children: [
          // Background story visual
          Positioned.fill(
            child: Image.asset(widget.story.storyImage, fit: BoxFit.cover),
          ),

          // Gradient overlay for contrast
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Top progress bar and user header
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated progress bar
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progressController.value,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          SpotifyColors.accent,
                        ),
                        minHeight: 3,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Story author bar
                Row(
                  children: [
                    ChatAvatar(
                      avatarAsset: widget.story.avatarAsset,
                      avatarColor: widget.story.avatarColor,
                      avatarInitials: widget.story.avatarText,
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.story.username,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.story.time,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Caption and bottom reply bar
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.story.caption != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.story.caption!,
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

                // Quick emoji reactions
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickReactions.map((emoji) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => _sendReply(emoji),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: SpotifyColors.surface.withValues(
                                alpha: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Reply bar mirroring the direct chat input section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Plus button on the left (circle)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Attachments are not available in stories',
                              ),
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
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: scheme.onSurface,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Input pill with internal microphone / send button
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
                                  hintText:
                                      'Reply to ${widget.story.username}...',
                                  hintStyle: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            if (_replyController.text.trim().isEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.mic_none_rounded,
                                  color: scheme.onSurfaceVariant,
                                  size: 22,
                                ),
                                tooltip: 'Voice message',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Hold to record voice message',
                                      ),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              )
                            else
                              IconButton(
                                key: const ValueKey('story-send-button'),
                                icon: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: SpotifyColors.accent,
                                  size: 22,
                                ),
                                tooltip: 'Send reply',
                                onPressed: () =>
                                    _sendReply(_replyController.text),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
