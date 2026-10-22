import 'package:flutter/foundation.dart';

import 'chat_store.dart';
import 'notification_service.dart';

/// A message that arrived since the previous inbox snapshot.
@immutable
class IncomingMessageNotice {
  const IncomingMessageNotice({
    required this.chatId,
    required this.title,
    required this.body,
  });

  final String chatId;
  final String title;
  final String body;
}

/// Turns inbox snapshots into immediate local message notifications.
///
/// FCM delivery can lag by seconds, so while the app process is alive the
/// existing inbox listener doubles as a notification source. The first
/// snapshot only seeds the watcher; subsequent snapshots compare each chat's
/// `lastMessageId`. Messages sent by the signed-in user, cleared chats,
/// already-read chats and the chat currently on screen are ignored.
class MessageNotificationWatcher {
  MessageNotificationWatcher();

  static final MessageNotificationWatcher instance =
      MessageNotificationWatcher();

  final Map<String, String> _lastMessageIds = {};
  String? _myUid;
  String? _activeChatId;
  bool _seeded = false;

  /// The chat currently open on screen, if any.
  String? get activeChatId => _activeChatId;

  /// Prevents a notification for the open conversation.
  void setActiveChat(String chatId) {
    _activeChatId = chatId;
  }

  /// Clears [chatId] only if it is still the open conversation.
  void clearActiveChat(String chatId) {
    if (_activeChatId == chatId) _activeChatId = null;
  }

  /// Forgets all seen ids (e.g. after signing out).
  void reset() {
    _lastMessageIds.clear();
    _myUid = null;
    _activeChatId = null;
    _seeded = false;
  }

  /// Compares [inbox] with the previous snapshot and returns the chats whose
  /// newest message should be announced.
  List<IncomingMessageNotice> track(ChatInbox inbox, String myUid) {
    if (myUid.isEmpty) return const [];

    if (_myUid != myUid) {
      _myUid = myUid;
      _lastMessageIds.clear();
      _seeded = false;
    }

    final notices = <IncomingMessageNotice>[];
    final shouldNotify = _seeded;
    final current = <String, String>{};

    void visit({
      required String chatId,
      required String? messageId,
      required String? senderId,
      required bool cleared,
      required int unread,
      required String title,
      required String body,
    }) {
      if (messageId == null || messageId.isEmpty) return;
      current[chatId] = messageId;
      if (!shouldNotify) return;
      if (_lastMessageIds[chatId] == messageId) return;
      if (senderId == null || senderId == myUid) return;
      if (chatId == _activeChatId) return;
      if (cleared || unread <= 0) return;
      notices.add(
        IncomingMessageNotice(chatId: chatId, title: title, body: body),
      );
    }

    for (final chat in inbox.directChats) {
      visit(
        chatId: chat.id,
        messageId: chat.lastMessageId,
        senderId: chat.lastSenderId,
        cleared: chat.isCleared,
        unread: chat.visibleUnread,
        title: chat.peer.displayName,
        body: _bodyFor(chat.lastMessageType, chat.lastMessage),
      );
    }

    for (final group in inbox.groups) {
      final sender = group.lastSenderId == null
          ? null
          : group.profileFor(group.lastSenderId!);
      final title = group.lastSenderAnonymous
          ? 'Anonymous Sender'
          : sender?.displayName ?? 'New message';
      visit(
        chatId: group.id,
        messageId: group.lastMessageId,
        senderId: group.lastSenderId,
        cleared: group.isCleared,
        unread: group.visibleUnread,
        title: title,
        body: _bodyFor(group.lastMessageType, group.lastMessage),
      );
    }

    for (final entry in current.entries) {
      _lastMessageIds[entry.key] = entry.value;
    }
    _seeded = true;
    return notices;
  }

  /// Tracks [inbox] and posts a notification for every new message.
  Future<void> handleInbox(ChatInbox inbox, String myUid) async {
    final notices = track(inbox, myUid);
    for (final notice in notices) {
      await NotificationService.instance.showIncomingMessage(
        chatId: notice.chatId,
        title: notice.title,
        body: notice.body,
      );
    }
  }

  static String _bodyFor(String type, String text) {
    return switch (type) {
      'image' => 'Sent you a photo',
      'sticker' => 'Sent you a sticker',
      'voice' => 'Sent you a voice note',
      'library' => 'Sent you a document',
      _ => text.trim().isEmpty ? 'Sent you a message' : text.trim(),
    };
  }
}
