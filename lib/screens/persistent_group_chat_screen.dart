import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/direct_chat.dart';
import '../models/group_chat.dart';
import '../navigation/app_route.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/media_storage.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_emoji_picker.dart';
import '../widgets/floating_empty_state.dart';
import '../widgets/hold_to_record_button.dart';
import 'group_settings_screen.dart';

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
  bool _sendAnonymously = false;
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
          if (group != null && !group.anonymousMessagesEnabled) {
            _sendAnonymously = false;
          }
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

  bool get _canPost => _group?.canPost(_myUid) ?? false;

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _uploading) return;
    if (_group != null && !_canPost) {
      _showSnack('Only admins can send messages in this group.');
      return;
    }

    final group = _group;
    final anonymous =
        _sendAnonymously && (group?.anonymousMessagesEnabled ?? false);
    final reply = _replyTo;
    _textController.clear();
    setState(() {
      _replyTo = null;
      _sendAnonymously = false;
    });

    try {
      await ChatStore.instance.sendGroupText(
        chatId: widget.chatId,
        text: text,
        replyTo: reply?.toReplyPreview(),
        anonymous: anonymous,
      );
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _textController.text = text;
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
      setState(() {
        _replyTo = reply;
        _sendAnonymously = anonymous;
      });
      _showSnack(
        error is StateError
            ? error.message
            : 'Could not send that message. Check your connection.',
      );
    }
  }

  Future<void> _sendVoice(VoiceRecording recording) async {
    if (_uploading) return;
    if (_group != null && !_canPost) {
      _showSnack('Only admins can send messages in this group.');
      return;
    }

    final group = _group;
    final anonymous =
        _sendAnonymously && (group?.anonymousMessagesEnabled ?? false);
    final reply = _replyTo;
    setState(() => _uploading = true);
    try {
      await ChatStore.instance.sendGroupVoice(
        chatId: widget.chatId,
        filePath: recording.path,
        durationMs: recording.durationMs,
        waveform: recording.waveform,
        replyTo: reply?.toReplyPreview(),
        anonymous: anonymous,
      );
      if (!mounted) return;
      setState(() {
        _replyTo = null;
        _sendAnonymously = false;
      });
      _scrollToBottom();
    } on StateError catch (error) {
      _showSnack(error.message);
    } on MediaStorageException {
      _showSnack(
        'The voice note could not be uploaded. Try a shorter recording.',
      );
    } on FirebaseException catch (error) {
      _showSnack(
        error.code == 'permission-denied'
            ? 'Voice notes are not allowed in this chat yet.'
            : 'The voice note uploaded, but the message could not be sent.',
      );
    } catch (_) {
      _showSnack('Could not send that voice note. Check your connection.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_uploading) return;
    if (_group != null && !_canPost) {
      _showSnack('Only admins can send messages in this group.');
      return;
    }
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
    } on StateError catch (error) {
      _showSnack(error.message);
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
                LucideIcons.image,
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
                LucideIcons.camera,
                color: SpotifyColors.accent,
              ),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText),
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

  void _startReply(DirectMessage message) {
    setState(() => _replyTo = message);
    _inputFocus.requestFocus();
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
              leading: const Icon(LucideIcons.reply),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (message.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(LucideIcons.copy),
                title: const Text('Copy'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(LucideIcons.pencil),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(
                  LucideIcons.trash2,
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
        _startReply(message);
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
              backgroundColor: SpotifyColors.accent,
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

  Future<void> _openGroupSettings() async {
    final group = _group;
    if (group == null) return;
    final left = await Navigator.of(context).push<bool>(
      sharedAxisRoute<bool>(
        GroupSettingsScreen(
          chatId: widget.chatId,
          initialGroup: group,
          myUid: _myUid,
        ),
      ),
    );
    if (left == true && mounted) Navigator.of(context).pop();
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
                avatarUrl: group.photoUrl,
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
                  style: AppType.timestamp(
                    Theme.of(context).colorScheme,
                  ).copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
              const SizedBox(height: 10),
              ListTile(
                key: const ValueKey('group-settings-option'),
                leading: const Icon(
                  LucideIcons.settings,
                  color: SpotifyColors.accent,
                ),
                title: const Text(
                  'Group settings',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: const Text(
                  'Anonymous messages, posting permissions and admins',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    color: Colors.white54,
                  ),
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openGroupSettings();
                },
              ),
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
                        borderRadius: BorderRadius.circular(4),
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
          icon: const Icon(LucideIcons.chevronLeft, size: 20),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: InkWell(
          onTap: _showGroupInfo,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              ChatAvatar(
                avatarUrl: group?.photoUrl,
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
            icon: Icon(LucideIcons.moreVertical, color: scheme.onSurface),
            color: SpotifyColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showGroupInfo();
                case 'settings':
                  _openGroupSettings();
                case 'clear':
                  _clearChat();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'info', child: Text('Group info')),
              PopupMenuItem(value: 'settings', child: Text('Group settings')),
              PopupMenuItem(
                value: 'clear',
                child: Text(
                  'Clear chat',
                  style: TextStyle(color: SpotifyColors.accent),
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
                                  icon: LucideIcons.users,
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
                        senderIsAdmin:
                            group?.isAdmin(message.senderId) ?? false,
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
                            onReply: () => _startReply(message),
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
    final group = _group;
    if (group != null && !group.canPost(_myUid)) {
      return _buildLockedInputBar();
    }

    final reply = _replyTo;
    final hasText = _textController.text.trim().isNotEmpty;
    final canAnonymous = group?.anonymousMessagesEnabled ?? false;
    final anonymous = canAnonymous && _sendAnonymously;

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
          if (anonymous)
            Container(
              key: const ValueKey('group-anonymous-banner'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
              decoration: BoxDecoration(
                color: SpotifyColors.tagUrgent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SpotifyColors.tagUrgent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.eyeOff,
                    size: 15,
                    color: SpotifyColors.tagUrgent,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Sending as Anonymous Sender — your name will be hidden.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: SpotifyColors.tagUrgent.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _sendAnonymously = false),
                    icon: const Icon(LucideIcons.x, size: 16),
                    color: SpotifyColors.tagUrgent,
                  ),
                ],
              ),
            ),
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
                          reply.senderId == _myUid ? 'You' : reply.senderLabel,
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
                      LucideIcons.x,
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
                      LucideIcons.plus,
                      color: scheme.onSurface,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('group-emoji-button'),
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    await showChatEmojiPicker(
                      context: context,
                      controller: _textController,
                    );
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    width: 40,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: SpotifyColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.smile,
                      color: anonymous
                          ? SpotifyColors.tagUrgent
                          : scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: anonymous
                          ? SpotifyColors.tagUrgent.withValues(alpha: 0.55)
                          : Colors.transparent,
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 14, right: 4),
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
                            hintText: anonymous
                                ? 'Send anonymously…'
                                : 'Message',
                            hintStyle: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: anonymous
                                  ? SpotifyColors.tagUrgent.withValues(
                                      alpha: 0.7,
                                    )
                                  : scheme.onSurfaceVariant,
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
                      if (canAnonymous)
                        IconButton(
                          key: const ValueKey('group-anonymous-toggle'),
                          icon: Icon(
                            LucideIcons.eyeOff,
                            color: anonymous
                                ? SpotifyColors.tagUrgent
                                : scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          tooltip: anonymous
                              ? 'Send with your name'
                              : 'Send anonymously',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(
                            () => _sendAnonymously = !_sendAnonymously,
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
                            LucideIcons.arrowUp,
                            color: SpotifyColors.accent,
                            size: 22,
                          ),
                          tooltip: 'Send message',
                          onPressed: _send,
                        )
                      else
                        HoldToRecordButton(
                          key: const ValueKey('group-voice-button'),
                          onRecorded: _sendVoice,
                          onMessage: _showSnack,
                          color: scheme.onSurfaceVariant,
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

  Widget _buildLockedInputBar() {
    return Container(
      key: const ValueKey('group-posting-locked'),
      color: SpotifyColors.background,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SpotifyColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.lock,
              size: 18,
              color: SpotifyColors.tagUrgent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Only admins can send messages',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The group is in announcement mode.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.5),
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
          avatarUrl: group?.photoUrl,
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
        if (group != null && group.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              group.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
        if (group != null && !group.membersCanPost) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.lock,
                size: 12,
                color: SpotifyColors.tagUrgent,
              ),
              const SizedBox(width: 4),
              Text(
                'Only admins can send messages',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SpotifyColors.tagUrgent.withValues(alpha: 0.9),
                ),
              ),
            ],
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
              borderRadius: BorderRadius.circular(4),
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
            style: AppType.timestamp(
              Theme.of(context).colorScheme,
            ).copyWith(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      ),
    );
  }
}
