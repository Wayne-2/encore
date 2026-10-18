import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_bubble.dart';

/// WhatsApp-style group chat interface with Admin Anonymous Mode.
///
/// Features:
/// - WhatsApp group chrome: group avatar, member roster preview, voice & video
///   call actions, and popup menu.
/// - End-to-end encryption card and date separator chips.
/// - WhatsApp-style incoming (with colored member names) and outgoing bubbles.
/// - **Paperclip Icon (Attachment Menu)**:
///   Contains WhatsApp attachment options (Document, Camera, Gallery, Audio,
///   Location, Contact, Poll) along with an **Admin Anonymous Mode toggle**.
/// - In **Anonymous Mode**, outgoing messages hide the sender ID completely,
///   and incoming anonymous messages display no individual identity.
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;

  /// Whether the user (as admin) has entered Anonymous Mode via the paperclip icon.
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

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    setState(() {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          text: text,
          time: timeStr,
          isMe: true,
          isAnonymous: _isAnonymousMode,
          senderName: _isAnonymousMode ? null : 'You',
        ),
      );
      _textController.clear();
    });

    _scrollToBottom();
  }

  void _toggleAnonymousMode([bool? forceValue]) {
    setState(() {
      _isAnonymousMode = forceValue ?? !_isAnonymousMode;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isAnonymousMode
            ? SpotifyColors.accent
            : SpotifyColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              _isAnonymousMode
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _isAnonymousMode ? Colors.white : SpotifyColors.accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isAnonymousMode
                    ? 'Anonymous Mode enabled: Messages will have no sender ID.'
                    : 'Normal Mode restored: Messages will show your ID.',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
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
                  color: SpotifyColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: SpotifyColors.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
                              'Camera opened (with Gallery access)',
                            ),
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
                          const SnackBar(content: Text('Audio picker opened')),
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: InkWell(
          onTap: () => _showGroupInfo(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
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
                        widget.conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.conversation.membersDescription.isNotEmpty
                            ? widget.conversation.membersDescription
                            : 'tap here for group info',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('chat-three-dots-menu'),
            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurface),
            color: SpotifyColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (val) {
              if (val == 'call') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Starting voice call with ${widget.conversation.title}...',
                    ),
                  ),
                );
              } else if (val == 'video_call') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Starting video call with ${widget.conversation.title}...',
                    ),
                  ),
                );
              } else if (val == 'anon') {
                _toggleAnonymousMode();
              } else if (val == 'info') {
                _showGroupInfo(context);
              } else if (val == 'media') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Group media & docs')),
                );
              } else if (val == 'search') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search in conversation')),
                );
              } else if (val == 'mute') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications muted')),
                );
              } else if (val == 'clear') {
                setState(() {
                  _messages.clear();
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'call',
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Voice Call',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'video_call',
                child: Row(
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Video Call',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
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
                      color: SpotifyColors.accent,
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
                          color: SpotifyColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Group info',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'media',
                child: Row(
                  children: [
                    Icon(
                      Icons.perm_media_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Group media, links, and docs',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mute notifications',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
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
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: SpotifyColors.danger,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear chat',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: SpotifyColors.danger,
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
          // Top right Anonymous Mode status pill (segmented design architecture)
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

          // WhatsApp doodle/dark chat background with message stream
          Expanded(
            child: Container(
              color: SpotifyColors.background,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  // Index 0: Header with encryption card & date badge
                  if (index == 0) {
                    return Column(
                      children: [
                        const SizedBox(height: 14),
                        ChatAvatar(
                          avatarAsset: widget.conversation.avatarAsset,
                          avatarColor: widget.conversation.avatarColor,
                          avatarInitials: widget.conversation.avatarInitials,
                          size: 72,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.conversation.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Group • ${widget.conversation.membersDescription.isNotEmpty ? widget.conversation.membersDescription : '5 participants'}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => _showGroupInfo(context),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: SpotifyColors.surface,
                            foregroundColor: scheme.onSurface,
                            side: const BorderSide(color: SpotifyColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'Group info',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Encryption disclaimer
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: SpotifyColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🔒 Messages and calls are end-to-end encrypted. No one outside of this chat, not even Encore, can read or listen to them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Date badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SpotifyColors.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TODAY',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  }

                  final message = _messages[index - 1];
                  return ChatBubble(message: message, showSender: true);
                },
              ),
            ),
          ),

          // WhatsApp Bottom Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: SpotifyColors.background,
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
                      ? SpotifyColors.surfaceHover
                      : SpotifyColors.surface,
                  shape: BoxShape.circle,
                  border: _isAnonymousMode
                      ? Border.all(
                          color: SpotifyColors.accent.withValues(alpha: 0.6),
                          width: 1.2,
                        )
                      : null,
                ),
                child: AnimatedRotation(
                  turns: _isAttachmentMenuOpen ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.add_rounded,
                    color: scheme.onSurface,
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
                color: SpotifyColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: _isAnonymousMode
                    ? Border.all(
                        color: SpotifyColors.accent.withValues(alpha: 0.8),
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
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: scheme.onSurface,
                        fontSize: 15,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: _isAnonymousMode ? 'Anonymous...' : 'Message',
                        hintStyle: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: _isAnonymousMode
                              ? SpotifyColors.accent.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
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
                      icon: Icon(
                        Icons.mic_none_rounded,
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
                      key: const ValueKey('send-button'),
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: SpotifyColors.accent,
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

  void _showGroupInfo(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatAvatar(
                avatarAsset: widget.conversation.avatarAsset,
                avatarColor: widget.conversation.avatarColor,
                avatarInitials: widget.conversation.avatarInitials,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                widget.conversation.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Group • ${widget.conversation.membersDescription}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.group, color: SpotifyColors.accent),
                title: const Text('Group Members (48)'),
                subtitle: const Text('View and manage group participants'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: SpotifyColors.accent,
                ),
                title: const Text('Admin Settings'),
                subtitle: const Text(
                  'Anonymous mode permissions & broadcast rules',
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;

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
                color: SpotifyColors.surfaceHover,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: scheme.onSurface, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A segmented capsule displaying the active anonymous condition and dismiss control.
///
/// Design Architecture:
/// - State indicator segment: Glowing green pulse dot + incognito badge glyph.
/// - Micro-typography segment: Tracked uppercase category ('ANONYMOUS') paired
///   with status ('ID Hidden').
/// - Divider segment: Subtle vertical hairline separator.
/// - Action segment: Tactile 'Turn off' pill with power glyph.
class _AnonymousStatusPill extends StatelessWidget {
  const _AnonymousStatusPill({required this.onTurnOff});

  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: SpotifyColors.accent.withValues(alpha: 0.5),
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
            color: SpotifyColors.accent,
          ),
          const SizedBox(width: 7),
          Text(
            'Anonymous',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),

          // Divider
          Container(
            width: 1,
            height: 14,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                  color: SpotifyColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SpotifyColors.danger.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Turn Off',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: SpotifyColors.danger,
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
