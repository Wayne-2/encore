import 'package:flutter/material.dart';

import '../models/chat_conversation.dart';
import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';
import '../widgets/chat_avatar.dart';

/// WhatsApp-style 1-on-1 direct chat interface.
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
        ),
      );
      _textController.clear();
    });

    _scrollToBottom();
  }

  void _openAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachmentIcon(
                    icon: Icons.insert_drive_file_rounded,
                    color: const Color(0xFF7F66FF),
                    label: 'Document',
                    onTap: () => Navigator.pop(context),
                  ),
                  _AttachmentIcon(
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFFD3396D),
                    label: 'Camera',
                    onTap: () => Navigator.pop(context),
                  ),
                  _AttachmentIcon(
                    icon: Icons.image_rounded,
                    color: const Color(0xFFAC44CF),
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context),
                  ),
                  _AttachmentIcon(
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
                  _AttachmentIcon(
                    icon: Icons.location_on_rounded,
                    color: const Color(0xFF1FA855),
                    label: 'Location',
                    onTap: () => Navigator.pop(context),
                  ),
                  _AttachmentIcon(
                    icon: Icons.person_rounded,
                    color: const Color(0xFF0298DB),
                    label: 'Contact',
                    onTap: () => Navigator.pop(context),
                  ),
                  _AttachmentIcon(
                    icon: Icons.payment_rounded,
                    color: SlackColors.accentGreen,
                    label: 'Send Funds',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 54), // spacer for balance
                ],
              ),
            ],
          ),
        ),
      ),
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
                    widget.conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
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
                      color: widget.conversation.membersDescription.toLowerCase().contains('online')
                          ? SlackColors.accentGreen
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            color: scheme.onSurface,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, size: 22),
            color: scheme.onSurface,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            color: scheme.onSurface,
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF0F1418),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      children: [
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
                  final isMe = message.isMe;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFF005C4B)
                                : const Color(0xFF202C33),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: isMe
                                  ? const Radius.circular(12)
                                  : Radius.zero,
                              bottomRight: isMe
                                  ? Radius.zero
                                  : const Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                },
              ),
            ),
          ),
          Container(
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
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF202C33),
                      borderRadius: BorderRadius.circular(24),
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
                            decoration: const InputDecoration(
                              filled: false,
                              fillColor: Colors.transparent,
                              hintText: 'Message',
                              hintStyle: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Color(0xFF8696A0),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Transform.rotate(
                            angle: -0.6,
                            child: const Icon(
                              Icons.attach_file_rounded,
                              color: Color(0xFF8696A0),
                              size: 24,
                            ),
                          ),
                          onPressed: _openAttachmentMenu,
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: SlackColors.accentGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    key: const ValueKey('direct-send-button'),
                    icon: Icon(
                      _textController.text.trim().isEmpty
                          ? Icons.mic_rounded
                          : Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed:
                        _textController.text.trim().isEmpty ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  const _AttachmentIcon({
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
