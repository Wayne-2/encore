import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';
import '../widgets/chat_avatar.dart';

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
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
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
        backgroundColor:
            _isAnonymousMode ? const Color(0xFF0F392B) : SlackColors.darkSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              _isAnonymousMode
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _isAnonymousMode
                  ? SlackColors.accentGreen
                  : Colors.white,
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

  /// Opens the WhatsApp attachment tray when tapping the paperclip icon.
  void _openAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1F2C34),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull handle
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // WhatsApp Standard Attachment Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _AttachmentItem(
                          icon: Icons.insert_drive_file_rounded,
                          color: const Color(0xFF7F66FF),
                          label: 'Document',
                          onTap: () => Navigator.pop(context),
                        ),
                        _AttachmentItem(
                          icon: Icons.camera_alt_rounded,
                          color: const Color(0xFFD3396D),
                          label: 'Camera',
                          onTap: () => Navigator.pop(context),
                        ),
                        _AttachmentItem(
                          icon: Icons.image_rounded,
                          color: const Color(0xFFAC44CF),
                          label: 'Gallery',
                          onTap: () => Navigator.pop(context),
                        ),
                        _AttachmentItem(
                          icon: Icons.headphones_rounded,
                          color: const Color(0xFFE07138),
                          label: 'Audio',
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _AttachmentItem(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFF1FA855),
                          label: 'Location',
                          onTap: () => Navigator.pop(context),
                        ),
                        _AttachmentItem(
                          icon: Icons.person_rounded,
                          color: const Color(0xFF0298DB),
                          label: 'Contact',
                          onTap: () => Navigator.pop(context),
                        ),
                        _AttachmentItem(
                          icon: Icons.bar_chart_rounded,
                          color: const Color(0xFF00A884),
                          label: 'Poll',
                          onTap: () => Navigator.pop(context),
                        ),
                        _AttachmentItem(
                          key: const ValueKey('anon-grid-button'),
                          icon: Icons.visibility_off_rounded,
                          color: _isAnonymousMode
                              ? SlackColors.accentGreen
                              : const Color(0xFF4A5568),
                          label: _isAnonymousMode ? 'Anon ON' : 'Anon OFF',
                          onTap: () {
                            setModalState(() {
                              _isAnonymousMode = !_isAnonymousMode;
                            });
                            _toggleAnonymousMode(_isAnonymousMode);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SlackColors.darkBackground,
      appBar: AppBar(
        backgroundColor: SlackColors.darkHeader,
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
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            color: scheme.onSurface,
            tooltip: 'Video call',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, size: 22),
            color: scheme.onSurface,
            tooltip: 'Voice call',
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: scheme.onSurface),
            color: SlackColors.darkSurface,
            onSelected: (val) {
              if (val == 'anon') {
                _toggleAnonymousMode();
              } else if (val == 'info') {
                _showGroupInfo(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'info', child: Text('Group info')),
              const PopupMenuItem(
                value: 'media',
                child: Text('Group media, links, and docs'),
              ),
              const PopupMenuItem(value: 'search', child: Text('Search')),
              const PopupMenuItem(
                value: 'mute',
                child: Text('Mute notifications'),
              ),
              PopupMenuItem(
                value: 'anon',
                child: Row(
                  children: [
                    Icon(
                      _isAnonymousMode
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 18,
                      color: SlackColors.accentGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAnonymousMode
                          ? 'Disable Anonymous Mode'
                          : 'Enter Anonymous Mode',
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
              color: const Color(0xFF0F1418),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  // Index 0: Header with encryption card & date badge
                  if (index == 0) {
                    return Column(
                      children: [
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
                            color: const Color(0xFF182229),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🔒 Messages and calls are end-to-end encrypted. No one outside of this chat, not even Encore, can read or listen to them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: Color(0xFFECC272),
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
                              color: const Color(0xFF182229),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8696A0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  }

                  final message = _messages[index - 1];
                  return _GroupMessageBubble(message: message);
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
    return Container(
      color: SlackColors.darkBackground,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 6,
        bottom: 6 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Input pill
          Expanded(
            child: Container(
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Color(0xFF8696A0),
                      size: 24,
                    ),
                    onPressed: () {},
                  ),
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
                        hintText: _isAnonymousMode
                            ? 'Anonymous...'
                            : 'Message',
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
                          horizontal: 4,
                        ),
                      ),
                    ),
                  ),
                  // The WhatsApp paperclip icon: enters anonymous mode
                  Stack(
                    children: [
                      IconButton(
                        key: const ValueKey('paperclip-icon'),
                        icon: Transform.rotate(
                          angle: -0.6,
                          child: Icon(
                            Icons.attach_file_rounded,
                            color: _isAnonymousMode
                                ? SlackColors.accentGreen
                                : const Color(0xFF8696A0),
                            size: 24,
                          ),
                        ),
                        tooltip: 'Attachment & Anonymous Mode',
                        onPressed: _openAttachmentMenu,
                      ),
                      if (_isAnonymousMode)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: SlackColors.accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF8696A0),
                      size: 22,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Send or Voice Record circular button
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: SlackColors.accentGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const ValueKey('send-button'),
              icon: Icon(
                _textController.text.trim().isEmpty
                    ? Icons.mic_rounded
                    : Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: _textController.text.trim().isEmpty ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SlackColors.darkSurface,
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
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Group • ${widget.conversation.membersDescription}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.group, color: SlackColors.accentGreen),
                title: const Text('Group Members (48)'),
                subtitle: const Text('View and manage group participants'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: SlackColors.accentGreen,
                ),
                title: const Text('Admin Settings'),
                subtitle: const Text('Anonymous mode permissions & broadcast rules'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WhatsApp Attachment Menu item.
class _AttachmentItem extends StatelessWidget {
  const _AttachmentItem({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFD1D2D3),
            ),
          ),
        ],
      ),
    );
  }
}

/// A WhatsApp-style group message bubble.
class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isNotice) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF182229),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11.5,
            color: Color(0xFFECC272),
          ),
        ),
      );
    }

    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            decoration: BoxDecoration(
              // WhatsApp dark green for outgoing, slate for incoming
              color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender Identification row
                if (!isMe) ...[
                  if (message.isAnonymous) ...[
                    // Anonymous incoming message: no sender identity shown
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_off_rounded,
                          size: 13,
                          color: Color(0xFFECC272),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Anonymous Member',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFECC272).withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ] else if (message.senderName != null) ...[
                    // Normal incoming group message: colorful sender name
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.senderName!,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: message.senderColor ?? SlackColors.accentGreen,
                          ),
                        ),
                        if (message.isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8696A0),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                ] else if (message.isAnonymous) ...[
                  // For outgoing anonymous message: private indicator that sender ID is concealed
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_off_rounded,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sent anonymously (No sender ID)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],

                // Message Text
                Text(
                  message.text,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.5,
                    height: 1.3,
                    color: Color(0xFFE9EDEF),
                  ),
                ),
                const SizedBox(height: 3),

                // Timestamp & Checkmarks
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Spacer(),
                    Text(
                      message.time,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : const Color(0xFF8696A0),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 15,
                        color: Color(0xFF53BDEB),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
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
