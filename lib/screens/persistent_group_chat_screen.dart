import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/direct_chat.dart';
import '../models/group_chat.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/floating_empty_state.dart';

/// Telegram-style group chat backed by Firestore.
///
/// Incoming messages show the sender's username above the bubble; the current
/// user's messages are right-aligned without repeating their own name.
class PersistentGroupChatScreen extends StatefulWidget {
  const PersistentGroupChatScreen({
    super.key,
    required this.chatId,
    this.initialGroup,
    this.groupStream,
    this.messagesStream,
  });

  final String chatId;
  final GroupChat? initialGroup;

  /// Injectable streams used by widget tests without Firebase.
  final Stream<GroupChat?>? groupStream;
  final Stream<List<DirectMessage>>? messagesStream;

  @override
  State<PersistentGroupChatScreen> createState() =>
      _PersistentGroupChatScreenState();
}

class _PersistentGroupChatScreenState extends State<PersistentGroupChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  StreamSubscription<GroupChat?>? _groupSubscription;
  StreamSubscription<List<DirectMessage>>? _messagesSubscription;

  late GroupChat? _group = widget.initialGroup;
  List<DirectMessage> _messages = const [];
  DirectMessage? _replyTo;
  bool _uploading = false;
  bool _markingRead = false;
  bool _initialLoad = true;

  String get _myUid => AuthService.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (_group != null) _initialLoad = false;
    _subscribe();
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    _messagesSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _subscribe() {
    final groupStream =
        widget.groupStream ?? ChatStore.instance.watchGroup(widget.chatId);
    _groupSubscription = groupStream.listen(
      (group) {
        if (!mounted) return;
        setState(() {
          _group = group;
          _initialLoad = false;
        });
        _maybeMarkRead();
      },
      onError: (Object _) {
        if (!mounted) return;
        setState(() => _initialLoad = false);
        _showSnack('Could not load this group.');
      },
    );

    final messagesStream =
        widget.messagesStream ??
        ChatStore.instance.watchMessages(widget.chatId);
    _messagesSubscription = messagesStream.listen(
      (messages) {
        if (!mounted) return;
        final previousCount = _messages.length;
        final position = _scrollController.hasClients
            ? _scrollController.position
            : null;
        final nearBottom =
            position == null ||
            position.maxScrollExtent - position.pixels < 160;
        final mine = messages.isNotEmpty && messages.last.senderId == _myUid;
        setState(() {
          _messages = messages;
          _initialLoad = false;
        });
        _maybeMarkRead();
        if (messages.length != previousCount &&
            (previousCount == 0 || nearBottom || mine)) {
          _scrollToBottom();
        }
      },
      onError: (Object _) {
        if (!mounted) return;
        setState(() => _initialLoad = false);
        _showSnack('Could not load messages.');
      },
    );
  }

  List<DirectMessage> get _visibleMessages {
    final cutoff = _group?.clearedAt;
    if (cutoff == null) return _messages;
    return _messages
        .where(
          (message) =>
              message.createdAt == null || message.createdAt!.isAfter(cutoff),
        )
        .toList(growable: false);
  }

  void _maybeMarkRead() {
    final group = _group;
    if (group == null || group.visibleUnread == 0 || _markingRead) return;
    _markingRead = true;
    unawaited(
      ChatStore.instance.markRead(widget.chatId).whenComplete(() {
        _markingRead = false;
      }),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _uploading) return;

    final reply = _replyTo;
    _textController.clear();
    setState(() => _replyTo = null);

    try {
      await ChatStore.instance.sendGroupText(
        chatId: widget.chatId,
        text: text,
        replyTo: reply?.toReplyPreview(),
      );
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      _textController.text = text;
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
      setState(() => _replyTo = reply);
      _showSnack('Could not send that message. Check your connection.');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_uploading) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() => _uploading = true);
      await ChatStore.instance.sendGroupImage(
        chatId: widget.chatId,
        bytes: bytes,
        filename: file.name,
      );
      _scrollToBottom();
    } on PlatformException catch (error) {
      _showSnack(error.message ?? 'Could not open the photo picker.');
    } catch (_) {
      _showSnack('Could not send that photo. Check your connection.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('group-photo-action'),
              leading: const Icon(
                Icons.photo_outlined,
                color: SpotifyColors.accent,
              ),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              key: const ValueKey('group-camera-action'),
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: SpotifyColors.accent,
              ),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Document'),
              subtitle: const Text('Coming soon'),
              onTap: () {
                Navigator.pop(context);
                _showSnack('Document sharing is coming soon.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActions(DirectMessage message) async {
    if (message.deleted) return;
    final mine = message.isMine(_myUid);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (message.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: SpotifyColors.danger,
                ),
                title: const Text(
                  'Delete for everyone',
                  style: TextStyle(color: SpotifyColors.danger),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'reply':
        setState(() => _replyTo = message);
        _inputFocus.requestFocus();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        _showSnack('Copied');
      case 'edit':
        await _editMessage(message);
      case 'delete':
        await _deleteMessage(message);
    }
  }

  Future<void> _editMessage(DirectMessage message) async {
    final controller = TextEditingController(text: message.text);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || next == null || next.isEmpty || next == message.text) {
      return;
    }

    try {
      await ChatStore.instance.editMessage(
        chatId: widget.chatId,
        messageId: message.id,
        text: next,
      );
    } catch (_) {
      _showSnack('Could not edit that message.');
    }
  }

  Future<void> _deleteMessage(DirectMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Delete message?'),
        content: const Text(
          'This will remove the message for everyone in this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: SpotifyColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ChatStore.instance.deleteMessage(
        chatId: widget.chatId,
        messageId: message.id,
      );
    } catch (_) {
      _showSnack('Could not delete that message.');
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.surface,
        title: const Text('Clear chat?'),
        content: const Text(
          'This removes your copy of the conversation. Other members keep '
          'their messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: SpotifyColors.danger,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ChatStore.instance.clearChat(widget.chatId);
    } catch (_) {
      _showSnack('Could not clear this chat.');
    }
  }

  void _showGroupInfo() {
    final group = _group;
    if (group == null) return;
    final members = group.members
        .map(
          (uid) =>
              group.profileFor(uid) ??
              ChatUser(id: uid, name: 'Member', username: ''),
        )
        .toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.68,
          child: Column(
            children: [
              const SizedBox(height: 18),
              ChatAvatar(
                avatarColor: group.avatarColor,
                avatarInitials: group.initials,
                size: 72,
              ),
              const SizedBox(height: 12),
              Text(
                group.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Group • ${group.memberCount} members',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: SpotifyColors.accent,
                ),
              ),
              if (group.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Created ${formatShortDate(group.createdAt!)}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1, color: SpotifyColors.border),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isMe = member.id == _myUid;
                    final isAdmin = group.isAdmin(member.id);
                    return ListTile(
                      leading: ChatAvatar(
                        avatarUrl: member.photoUrl,
                        avatarColor: member.avatarColor,
                        avatarInitials: member.initials,
                        size: 40,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              isMe ? 'You' : member.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: isMe
                                    ? SpotifyColors.accent
                                    : Colors.white,
                              ),
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: SpotifyColors.accent.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Admin',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: SpotifyColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        member.handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    );
                  },
                ),
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
    final group = _group;
    final messages = _visibleMessages;

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
          onTap: _showGroupInfo,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              ChatAvatar(
                avatarColor: group?.avatarColor,
                avatarInitials: group?.initials,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group?.title ?? 'Group',
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
                      group == null
                          ? 'Loading group…'
                          : '${group.memberCount} members',
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
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('group-chat-menu'),
            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurface),
            color: SpotifyColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showGroupInfo();
                case 'clear':
                  _clearChat();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'info', child: Text('Group info')),
              PopupMenuItem(
                value: 'clear',
                child: Text(
                  'Clear chat',
                  style: TextStyle(color: SpotifyColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _initialLoad && group == null && messages.isEmpty
                ? const Center(child: AppLoader())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          children: [
                            _GroupHeader(
                              group: group,
                              onViewInfo: _showGroupInfo,
                            ),
                            if (messages.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 30),
                                child: FloatingEmptyState(
                                  key: ValueKey('group-chat-empty'),
                                  icon: Icons.groups_outlined,
                                  message:
                                      'No messages yet. Start the conversation.',
                                ),
                              ),
                          ],
                        );
                      }

                      final message = messages[index - 1];
                      final previous = index > 1 ? messages[index - 2] : null;
                      final showDate =
                          message.createdAt != null &&
                          !isSameDay(previous?.createdAt, message.createdAt);
                      final sender = group?.profileFor(message.senderId);
                      final uiMessage = message.toUiMessage(
                        myUid: _myUid,
                        isSeen:
                            group?.isReadByEveryone(message, _myUid) ?? false,
                        showUsername: true,
                        sender: sender,
                      );

                      return Column(
                        children: [
                          if (showDate)
                            _DateSeparator(
                              label: formatDateSeparator(message.createdAt),
                            ),
                          ChatBubble(
                            key: ValueKey('group-message-${message.id}'),
                            message: uiMessage,
                            showSender: true,
                            onLongPress: () => _showMessageActions(message),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final scheme = Theme.of(context).colorScheme;
    final reply = _replyTo;
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      color: SpotifyColors.background,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 6,
        bottom: MediaQuery.viewInsetsOf(context).bottom > 0
            ? 8
            : 8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply != null)
            Container(
              key: const ValueKey('group-reply-preview'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(
                color: SpotifyColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: SpotifyColors.accent, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reply.senderId == _myUid ? 'You' : reply.senderName,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SpotifyColors.accent,
                          ),
                        ),
                        Text(
                          reply.toReplyPreview().preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyTo = null),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('group-plus-button'),
                  borderRadius: BorderRadius.circular(22),
                  onTap: _openAttachmentMenu,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: SpotifyColors.surface,
                      shape: BoxShape.circle,
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
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('group-message-input'),
                          controller: _textController,
                          focusNode: _inputFocus,
                          maxLines: 4,
                          minLines: 1,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: scheme.onSurface,
                            fontSize: 15,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Message',
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
                      if (_uploading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SpotifyColors.accent,
                            ),
                          ),
                        )
                      else if (hasText)
                        IconButton(
                          key: const ValueKey('group-send-button'),
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            color: SpotifyColors.accent,
                            size: 22,
                          ),
                          tooltip: 'Send message',
                          onPressed: _send,
                        )
                      else
                        IconButton(
                          icon: Icon(
                            Icons.mic_none_rounded,
                            color: scheme.onSurfaceVariant,
                            size: 22,
                          ),
                          tooltip: 'Voice message',
                          onPressed: () =>
                              _showSnack('Voice messages are coming soon.'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.onViewInfo});

  final GroupChat? group;
  final VoidCallback onViewInfo;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    return Column(
      children: [
        const SizedBox(height: 18),
        ChatAvatar(
          avatarColor: group?.avatarColor,
          avatarInitials: group?.initials,
          size: 76,
        ),
        const SizedBox(height: 12),
        Text(
          group?.title ?? 'Group',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          group == null
              ? 'Loading group…'
              : 'Group • ${group.memberCount} members',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: SpotifyColors.accent,
          ),
        ),
        if (group != null && group.membersDescription.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              group.membersDescription,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onViewInfo,
          style: OutlinedButton.styleFrom(
            backgroundColor: SpotifyColors.surface,
            foregroundColor: Colors.white,
            side: const BorderSide(color: SpotifyColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          ),
          child: const Text(
            'Group info',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
