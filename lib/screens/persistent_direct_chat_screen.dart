import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/direct_chat.dart';
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

/// Telegram-style direct message screen backed by Firestore.
///
/// The legacy [DirectChatScreen] remains as the offline/demo screen used by
/// widget tests; signed-in users always land here.
class PersistentDirectChatScreen extends StatefulWidget {
  const PersistentDirectChatScreen({
    super.key,
    required this.chatId,
    required this.peer,
  });

  final String chatId;
  final ChatUser peer;

  @override
  State<PersistentDirectChatScreen> createState() =>
      _PersistentDirectChatScreenState();
}

class _PersistentDirectChatScreenState extends State<PersistentDirectChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  StreamSubscription<DirectChat>? _chatSubscription;
  StreamSubscription<List<DirectMessage>>? _messagesSubscription;
  Timer? _clock;
  Timer? _presence;
  Timer? _focusScroll;

  DirectChat? _chat;
  List<DirectMessage> _messages = const [];
  DirectMessage? _replyTo;
  DateTime _now = DateTime.now();
  DateTime? _lastTypingWrite;
  bool _typingActive = false;
  bool _uploading = false;
  bool _markingRead = false;
  bool _initialLoad = true;

  String get _myUid => AuthService.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _subscribe();
    unawaited(ChatStore.instance.markOnline());
    _presence = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(ChatStore.instance.markOnline());
    });
    _inputFocus.addListener(() {
      if (!_inputFocus.hasFocus) return;
      _focusScroll?.cancel();
      _focusScroll = Timer(const Duration(milliseconds: 250), () {
        if (mounted) _scrollToBottom();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTyping();
    _clock?.cancel();
    _presence?.cancel();
    _focusScroll?.cancel();
    _chatSubscription?.cancel();
    _messagesSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeMarkRead();
      unawaited(ChatStore.instance.markOnline());
    } else if (state == AppLifecycleState.paused) {
      _stopTyping();
    }
  }

  void _subscribe() {
    _chatSubscription = ChatStore.instance
        .watchChat(chatId: widget.chatId, peer: widget.peer)
        .listen(
          (chat) {
            if (!mounted) return;
            setState(() {
              _chat = chat;
              _initialLoad = false;
            });
            _maybeMarkRead();
          },
          onError: (Object _) {
            if (!mounted) return;
            setState(() => _initialLoad = false);
            _showSnack('Could not load this conversation.');
          },
        );

    _messagesSubscription = ChatStore.instance
        .watchMessages(widget.chatId)
        .listen(
          (messages) {
            if (!mounted) return;
            final previousCount = _messages.length;
            final position = _scrollController.hasClients
                ? _scrollController.position
                : null;
            final nearBottom =
                position == null ||
                position.maxScrollExtent - position.pixels < 160;
            final mine =
                messages.isNotEmpty && messages.last.senderId == _myUid;
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
    final cutoff = _chat?.clearedAt;
    if (cutoff == null) return _messages;
    return _messages
        .where(
          (message) =>
              message.createdAt == null || message.createdAt!.isAfter(cutoff),
        )
        .toList(growable: false);
  }

  bool _isSeenByPeer(DirectMessage message) {
    final readAt = _chat?.peerLastReadAt;
    final sentAt = message.createdAt;
    if (readAt == null || sentAt == null) return false;
    return !readAt.isBefore(sentAt);
  }

  void _maybeMarkRead() {
    final chat = _chat;
    if (chat == null || chat.visibleUnread == 0 || _markingRead) return;
    _markingRead = true;
    unawaited(
      ChatStore.instance.markRead(widget.chatId).whenComplete(() {
        _markingRead = false;
      }),
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _handleTyping(String value) {
    setState(() {});
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }

    final now = DateTime.now();
    final last = _lastTypingWrite;
    if (_typingActive &&
        last != null &&
        now.difference(last) < const Duration(seconds: 2)) {
      return;
    }

    _typingActive = true;
    _lastTypingWrite = now;
    unawaited(ChatStore.instance.setTyping(widget.chatId, true));
  }

  void _stopTyping() {
    if (!_typingActive) return;
    _typingActive = false;
    _lastTypingWrite = null;
    unawaited(ChatStore.instance.setTyping(widget.chatId, false));
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _uploading) return;

    final reply = _replyTo;
    _textController.clear();
    _stopTyping();
    setState(() => _replyTo = null);

    try {
      await ChatStore.instance.sendText(
        peer: widget.peer,
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

  Future<void> _sendVoice(VoiceRecording recording) async {
    if (_uploading) return;
    final reply = _replyTo;
    setState(() => _uploading = true);
    try {
      await ChatStore.instance.sendVoice(
        peer: widget.peer,
        filePath: recording.path,
        durationMs: recording.durationMs,
        waveform: recording.waveform,
        replyTo: reply?.toReplyPreview(),
      );
      if (!mounted) return;
      setState(() => _replyTo = null);
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
      await ChatStore.instance.sendImage(
        peer: widget.peer,
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
              key: const ValueKey('chat-photo-action'),
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
              key: const ValueKey('chat-camera-action'),
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
            ListTile(
              leading: const Icon(LucideIcons.headphones),
              title: const Text('Audio'),
              subtitle: const Text('Coming soon'),
              onTap: () {
                Navigator.pop(context);
                _showSnack('Audio messages are coming soon.');
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
          'This will remove the message for everyone in this chat.',
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
        content: Text(
          'This removes your copy of the conversation. '
          '${widget.peer.displayName} will still see their messages.',
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
      final cleared = await ChatStore.instance.clearChat(widget.chatId);
      if (!mounted) return;
      if (!cleared) {
        _showSnack('Could not clear this chat.');
        return;
      }
      setState(() => _messages = const []);
    } catch (_) {
      _showSnack('Could not clear this chat.');
    }
  }

  void _showProfile() {
    final chat = _chat;
    final peer = chat?.peer ?? widget.peer;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatAvatar(
                avatarUrl: peer.photoUrl,
                avatarColor: peer.avatarColor,
                avatarInitials: peer.initials,
                size: 72,
              ),
              const SizedBox(height: 12),
              Text(
                peer.displayName,
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
                peer.handle,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: SpotifyColors.accent,
                ),
              ),
              if ((peer.level ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  peer.level!,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                peer.presenceLabel(_now),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  color: peer.isOnlineAt(_now)
                      ? SpotifyColors.accent
                      : Colors.white.withValues(alpha: 0.55),
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
    final chat = _chat;
    final peer = chat?.peer ?? widget.peer;
    final typing = chat?.isTypingAt(_now) ?? false;
    final online = peer.isOnlineAt(_now);
    final subtitle = typing ? 'typing…' : peer.presenceLabel(_now);
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
          onTap: _showProfile,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              ChatAvatar(
                avatarUrl: peer.photoUrl,
                avatarColor: peer.avatarColor,
                avatarInitials: peer.initials,
                size: 40,
                showOnlineDot: online,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      peer.displayName,
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
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: typing || online
                            ? SpotifyColors.accent
                            : scheme.onSurfaceVariant,
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
            key: const ValueKey('persistent-chat-menu'),
            icon: Icon(LucideIcons.moreVertical, color: scheme.onSurface),
            color: SpotifyColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showProfile();
                case 'call':
                  _showSnack('Voice calls are coming soon.');
                case 'video':
                  _showSnack('Video calls are coming soon.');
                case 'clear':
                  _clearChat();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('View profile'),
              ),
              const PopupMenuItem(value: 'call', child: Text('Voice call')),
              const PopupMenuItem(value: 'video', child: Text('Video call')),
              const PopupMenuDivider(),
              const PopupMenuItem(
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
            child: _initialLoad && chat == null && messages.isEmpty
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
                            _ProfileHeader(
                              peer: peer,
                              chat: chat,
                              now: _now,
                              onViewProfile: _showProfile,
                            ),
                            if (messages.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 30),
                                child: FloatingEmptyState(
                                  key: ValueKey('persistent-chat-empty'),
                                  iconAsset: 'assets/icons/messages.svg',
                                  message: 'No messages yet. Say hi.',
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
                      final uiMessage = message.toUiMessage(
                        myUid: _myUid,
                        isSeen: _isSeenByPeer(message),
                      );

                      return Column(
                        children: [
                          if (showDate)
                            _DateSeparator(
                              label: formatDateSeparator(message.createdAt),
                            ),
                          ChatBubble(
                            key: ValueKey('persistent-message-${message.id}'),
                            message: uiMessage,
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
              key: const ValueKey('persistent-reply-preview'),
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
                  key: const ValueKey('persistent-plus-button'),
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
                  key: const ValueKey('persistent-emoji-button'),
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
                      color: scheme.onSurfaceVariant,
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
                  ),
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('persistent-message-input'),
                          controller: _textController,
                          focusNode: _inputFocus,
                          maxLines: 4,
                          minLines: 1,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: scheme.onSurface,
                            fontSize: 15,
                          ),
                          onChanged: _handleTyping,
                          decoration: InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
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
                          key: const ValueKey('persistent-send-button'),
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
                          key: const ValueKey('direct-voice-button'),
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.peer,
    required this.chat,
    required this.now,
    required this.onViewProfile,
  });

  final ChatUser peer;
  final DirectChat? chat;
  final DateTime now;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    final started = chat?.createdAt;
    return Column(
      children: [
        const SizedBox(height: 18),
        ChatAvatar(
          avatarUrl: peer.photoUrl,
          avatarColor: peer.avatarColor,
          avatarInitials: peer.initials,
          size: 76,
        ),
        const SizedBox(height: 12),
        Text(
          peer.displayName,
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
          peer.handle,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: SpotifyColors.accent,
          ),
        ),
        if ((peer.level ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            peer.level!,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          started == null
              ? peer.presenceLabel(now)
              : 'Chat started ${formatShortDate(started)}',
          style: AppType.timestamp(
            Theme.of(context).colorScheme,
          ).copyWith(color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onViewProfile,
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
            'View profile',
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
