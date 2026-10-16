import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';
import '../widgets/chat_avatar.dart';

/// WhatsApp / Instagram modern direct chat interface.
class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  bool _isAnonymousMode = false;
  bool _isAttachmentMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _messages = List<ChatMessage>.from(widget.conversation.initialMessages);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _toggleAnonymousMode([bool? forceState]) {
    setState(() {
      _isAnonymousMode = forceState ?? !_isAnonymousMode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isAnonymousMode
              ? 'Anonymous Mode activated: Outgoing chats omit sender identity'
              : 'Anonymous Mode disabled: Normal chat restored',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor:
            _isAnonymousMode ? SlackColors.accentGreen : const Color(0xFF333333),
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'pm' : 'am';
    final timeStr = '$hour:$minute $period';

    setState(() {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          text: text,
          time: timeStr,
          isMe: true,
          isAnonymous: _isAnonymousMode,
        ),
      );
      _textController.clear();
    });

    _scrollToBottom();
  }

  /// Opens the floating vertical plus menu anchored above the plus button.
  void _openAttachmentMenu() async {
    if (_isAttachmentMenuOpen) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _isAttachmentMenuOpen = true;
    });

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              bottom: 64 + MediaQuery.of(context).padding.bottom,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF202C33),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FloatingMenuItem(
                      key: const ValueKey('clip-attachment-item'),
                      icon: Icons.insert_drive_file_outlined,
                      label: 'Document',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Document picker opened'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _FloatingMenuItem(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Camera opened (with Gallery access)'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _FloatingMenuItem(
                      icon: Icons.headphones_outlined,
                      label: 'Audio',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Audio picker opened'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _isAttachmentMenuOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWayne = widget.conversation.title.toLowerCase().contains('wayne');
    final displayName = widget.conversation.title.contains('✨')
        ? widget.conversation.title
        : '${widget.conversation.title} ✨';

    return Scaffold(
      backgroundColor: SlackColors.darkBackground,
      appBar: AppBar(
        backgroundColor: SlackColors.darkHeader,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            ChatAvatar(
              avatarAsset: widget.conversation.avatarAsset,
              avatarColor: widget.conversation.avatarColor,
              avatarInitials: widget.conversation.avatarInitials,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.conversation.membersDescription.isNotEmpty
                        ? widget.conversation.membersDescription
                        : 'Online',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: widget.conversation.membersDescription
                              .toLowerCase()
                              .contains('online')
                          ? SlackColors.accentGreen
                          : const Color(0xFF8696A0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Three dots menu button ONLY (Voice Call, Video Call, Anonymous Mode, etc.)
          PopupMenuButton<String>(
            key: const ValueKey('chat-three-dots-menu'),
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: SlackColors.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (val) {
              if (val == 'call') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Starting voice call with ${widget.conversation.title}...'),
                  ),
                );
              } else if (val == 'video_call') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Starting video call with ${widget.conversation.title}...'),
                  ),
                );
              } else if (val == 'anon') {
                _toggleAnonymousMode();
              } else if (val == 'info') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Conversation info for ${widget.conversation.title}'),
                  ),
                );
              } else if (val == 'search') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search in conversation')),
                );
              } else if (val == 'clear') {
                setState(() {
                  _messages.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat cleared')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'call',
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 20, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Voice Call',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'video_call',
                child: Row(
                  children: [
                    Icon(Icons.videocam_outlined,
                        size: 20, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Video Call',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                key: const ValueKey('anon-menu-item'),
                value: 'anon',
                child: Row(
                  children: [
                    Icon(
                      _isAnonymousMode
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                      color: SlackColors.accentGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isAnonymousMode
                            ? 'Disable Anonymous Mode'
                            : 'Enter Anonymous Mode',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: SlackColors.accentGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: Color(0xFF8696A0)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Conversation info',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 20, color: Color(0xFF8696A0)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 20, color: Color(0xFFFF6B6B)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear chat',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Top right Anonymous Mode status pill
          if (_isAnonymousMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: _AnonymousStatusPill(
                  onTurnOff: () => _toggleAnonymousMode(false),
                ),
              ),
            ),

          Expanded(
            child: Container(
              color: const Color(0xFF0F1418),
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  // Index 0: Profile Header Card matching reference image
                  if (index == 0) {
                    return Column(
                      children: [
                        const SizedBox(height: 18),
                        ChatAvatar(
                          avatarAsset: widget.conversation.avatarAsset,
                          avatarColor: widget.conversation.avatarColor,
                          avatarInitials: widget.conversation.avatarInitials,
                          size: 76,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.conversation.title,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('✨', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.conversation.joinedDate ??
                              'Joined 11 August 2023',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: Color(0xFF8696A0),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.conversation.followersCount ?? 16} Followers',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: Color(0xFF8696A0),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Viewing profile for ${widget.conversation.title}'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF202C33),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'View profile',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE9EDEF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Date separator matching reference & test
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isWayne ? 'Today 5:43 pm' : 'TODAY',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8696A0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    );
                  }

                  final message = _messages[index - 1];
                  final isMe = message.isMe;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.76,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF0A84FF)
                                    : const Color(0xFF202C33),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (message.isAnonymous) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.visibility_off_rounded,
                                          size: 11,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Sent anonymously',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                  ],
                                  Text(
                                    message.text,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14.5,
                                      height: 1.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Status indicator underneath sent message matching reference
                        if (isMe)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 4),
                            child: Text(
                              isWayne
                                  ? (message.text == 'Yes sir 🫡'
                                      ? 'Sent'
                                      : 'Seen')
                                  : message.time,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10.5,
                                color: Color(0xFF8696A0),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Input Bar (plus button on left, input pill on right)
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: SlackColors.darkBackground,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Plus button on the left (circle)
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('plus-button'),
              borderRadius: BorderRadius.circular(22),
              onTap: _openAttachmentMenu,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                key: const ValueKey('paperclip-icon'),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isAttachmentMenuOpen
                      ? const Color(0xFF2C363C)
                      : const Color(0xFF202C33),
                  shape: BoxShape.circle,
                  border: _isAnonymousMode
                      ? Border.all(
                          color: SlackColors.accentGreen.withValues(alpha: 0.6),
                          width: 1.2,
                        )
                      : null,
                ),
                child: AnimatedRotation(
                  turns: _isAttachmentMenuOpen ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Input pill on the right with internal microphone / send button
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: const Color(0xFF202C33),
                borderRadius: BorderRadius.circular(24),
                border: _isAnonymousMode
                    ? Border.all(
                        color: SlackColors.accentGreen.withValues(alpha: 0.8),
                        width: 1.2,
                      )
                    : null,
              ),
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText:
                            _isAnonymousMode ? 'Anonymous...' : 'Message',
                        hintStyle: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: _isAnonymousMode
                              ? SlackColors.accentGreen.withValues(alpha: 0.8)
                              : const Color(0xFF8696A0),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  if (_textController.text.trim().isEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.mic_none_rounded,
                        color: Color(0xFF8696A0),
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
                      key: const ValueKey('direct-send-button'),
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: SlackColors.accentGreen,
                        size: 22,
                      ),
                      tooltip: 'Send message',
                      onPressed: _sendMessage,
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

class _FloatingMenuItem extends StatelessWidget {
  const _FloatingMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF2C363C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnonymousStatusPill extends StatelessWidget {
  const _AnonymousStatusPill({required this.onTurnOff});

  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF143024), Color(0xFF0C2219)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: SlackColors.accentGreen.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_off_rounded,
            size: 15,
            color: SlackColors.accentGreen,
          ),
          const SizedBox(width: 7),
          const Text(
            'Anonymous',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),

          // Divider
          Container(
            width: 1,
            height: 14,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 6),

          // Action segment: Turn Off
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('anon-turn-off-btn'),
              onTap: onTurnOff,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF381519),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Turn Off',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF7272),
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
