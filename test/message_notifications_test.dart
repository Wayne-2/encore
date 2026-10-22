import 'package:encore/models/direct_chat.dart';
import 'package:encore/models/group_chat.dart';
import 'package:encore/services/chat_store.dart';
import 'package:encore/services/message_notification_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

ChatUser _user(String id, String name, String username) {
  return ChatUser(id: id, name: name, username: username);
}

DirectChat _direct({
  String id = 'direct-1',
  String? lastMessageId = 'm1',
  String lastSenderId = 'peer',
  String lastMessage = 'Hello there',
  String lastMessageType = 'text',
  int unread = 1,
  DateTime? clearedAt,
}) {
  return DirectChat(
    id: id,
    peer: _user('peer', 'Ada Lovelace', 'ada'),
    members: const ['me', 'peer'],
    lastMessage: lastMessage,
    lastMessageId: lastMessageId,
    lastMessageType: lastMessageType,
    lastMessageAt: DateTime(2026, 1, 1),
    lastSenderId: lastSenderId,
    unreadCount: unread,
    clearedAt: clearedAt,
  );
}

GroupChat _group({
  String id = 'group-1',
  String? lastMessageId = 'g1',
  String lastSenderId = 'peer',
  bool anonymous = false,
  String lastMessage = 'Hello team',
  String lastMessageType = 'text',
  int unread = 1,
  DateTime? clearedAt,
}) {
  return GroupChat(
    id: id,
    title: 'Study group',
    members: const ['me', 'peer'],
    memberProfiles: {
      'peer': _user('peer', 'Grace Hopper', 'grace'),
    },
    adminIds: const ['me'],
    lastMessage: lastMessage,
    lastMessageId: lastMessageId,
    lastMessageType: lastMessageType,
    lastSenderId: lastSenderId,
    lastSenderAnonymous: anonymous,
    lastMessageAt: DateTime(2026, 1, 1),
    unreadCount: unread,
    clearedAt: clearedAt,
  );
}

ChatInbox _inbox({List<DirectChat> direct = const [], List<GroupChat> groups = const []}) {
  return ChatInbox(directChats: direct, groups: groups);
}

void main() {
  test('first snapshot seeds without notifying', () {
    final watcher = MessageNotificationWatcher();
    final notices = watcher.track(_inbox(direct: [_direct()]), 'me');
    expect(notices, isEmpty);
  });

  test('a new direct message becomes a notice once', () {
    final watcher = MessageNotificationWatcher();
    watcher.track(_inbox(direct: [_direct(lastMessageId: 'm1')]), 'me');

    final notices = watcher.track(
      _inbox(direct: [_direct(lastMessageId: 'm2')]),
      'me',
    );

    expect(notices, hasLength(1));
    expect(notices.single.chatId, 'direct-1');
    expect(notices.single.title, 'Ada Lovelace');
    expect(notices.single.body, 'Hello there');
    expect(
      watcher.track(_inbox(direct: [_direct(lastMessageId: 'm2')]), 'me'),
      isEmpty,
    );
  });

  test('suppresses own, active, cleared and already-read messages', () {
    final watcher = MessageNotificationWatcher();
    watcher.track(
      _inbox(
        direct: [
          _direct(id: 'own', lastMessageId: 'm1'),
          _direct(id: 'active', lastMessageId: 'm1'),
          _direct(id: 'cleared', lastMessageId: 'm1'),
          _direct(id: 'read', lastMessageId: 'm1'),
        ],
      ),
      'me',
    );
    watcher.setActiveChat('active');

    final notices = watcher.track(
      _inbox(
        direct: [
          _direct(id: 'own', lastMessageId: 'm2', lastSenderId: 'me'),
          _direct(id: 'active', lastMessageId: 'm2'),
          _direct(
            id: 'cleared',
            lastMessageId: 'm2',
            clearedAt: DateTime(2026, 1, 2),
          ),
          _direct(id: 'read', lastMessageId: 'm2', unread: 0),
        ],
      ),
      'me',
    );

    expect(notices, isEmpty);
  });

  test('group notices use sender name, anonymity and attachment labels', () {
    final watcher = MessageNotificationWatcher();
    watcher.track(_inbox(groups: [_group()]), 'me');

    final notices = watcher.track(
      _inbox(
        groups: [
          _group(
            lastMessageId: 'g2',
            lastMessageType: 'sticker',
            lastMessage: 'Sticker',
          ),
        ],
      ),
      'me',
    );
    expect(notices.single.title, 'Grace Hopper');
    expect(notices.single.body, 'Sent you a sticker');

    final anonymous = watcher.track(
      _inbox(
        groups: [
          _group(lastMessageId: 'g3', anonymous: true, lastMessage: 'hi'),
        ],
      ),
      'me',
    );
    expect(anonymous.single.title, 'Anonymous Sender');
    expect(anonymous.single.body, 'hi');
  });

  test('changing signed-in user reseeds the watcher', () {
    final watcher = MessageNotificationWatcher();
    watcher.track(_inbox(direct: [_direct(lastMessageId: 'm1')]), 'me');

    final notices = watcher.track(
      _inbox(direct: [_direct(lastMessageId: 'm2')]),
      'someone-else',
    );
    expect(notices, isEmpty);
  });
}
