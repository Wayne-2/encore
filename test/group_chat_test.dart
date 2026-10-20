import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/models/direct_chat.dart';
import 'package:encore/models/group_chat.dart';
import 'package:encore/screens/create_group_screen.dart';
import 'package:encore/screens/persistent_group_chat_screen.dart';

const _me = ChatUser(id: 'me', name: 'Wayne Doe', username: 'wayne');
const _ama = ChatUser(id: 'ama', name: 'Ama Mensah', username: 'ama');
const _kofi = ChatUser(id: 'kofi', name: 'Kofi Boateng', username: 'kofi');

GroupChat _group({
  String lastMessage = 'Question 4 is on the drive',
  String? lastSenderId = 'ama',
  Map<String, DateTime> lastReadAt = const {},
}) {
  return GroupChat(
    id: 'group-1',
    title: 'CSC 200 Study Group',
    members: const ['me', 'ama', 'kofi'],
    memberProfiles: const {'me': _me, 'ama': _ama, 'kofi': _kofi},
    adminIds: const ['me'],
    createdBy: 'me',
    lastMessage: lastMessage,
    lastSenderId: lastSenderId,
    lastMessageAt: DateTime(2026, 10, 20, 12),
    lastReadAt: lastReadAt,
    createdAt: DateTime(2026, 10, 19, 9),
  );
}

void main() {
  test('group conversation previews show the last sender username', () {
    final conversation = _group().toConversation(myUid: 'me');

    expect(conversation.isGroup, isTrue);
    expect(conversation.title, 'CSC 200 Study Group');
    expect(conversation.lastMessage, 'Question 4 is on the drive');
    expect(conversation.lastMessageSender, 'ama');
    expect(conversation.membersDescription, '3 members');
    expect(conversation.hasUnread, isFalse);
  });

  test('empty groups have no sender prefix and hide cleared previews', () {
    final empty = GroupChat(
      id: 'group-2',
      title: 'New group',
      members: const ['me', 'ama'],
      memberProfiles: const {'me': _me, 'ama': _ama},
      adminIds: const ['me'],
    );

    expect(empty.lastMessageSender, isNull);
    expect(empty.preview(), 'No messages yet');

    final cleared = GroupChat(
      id: 'group-1',
      title: 'CSC 200 Study Group',
      members: const ['me', 'ama'],
      memberProfiles: const {'me': _me, 'ama': _ama},
      adminIds: const ['me'],
      lastMessage: 'Old message',
      lastSenderId: 'ama',
      lastMessageAt: DateTime(2026, 10, 20, 12),
      clearedAt: DateTime(2026, 10, 20, 13),
      unreadCount: 4,
    );
    expect(cleared.visibleUnread, 0);
    expect(cleared.preview(), 'No messages yet');
  });

  test('group read state requires every other member to have read', () {
    final message = DirectMessage(
      id: 'm1',
      senderId: 'me',
      senderName: 'Wayne Doe',
      senderUsername: 'wayne',
      text: 'Hello',
      type: 'text',
      createdAt: DateTime(2026, 10, 20, 12),
    );

    expect(
      _group(
        lastReadAt: {
          'ama': DateTime(2026, 10, 20, 12, 5),
          'kofi': DateTime(2026, 10, 20, 12, 7),
        },
      ).isReadByEveryone(message, 'me'),
      isTrue,
    );
    expect(
      _group(
        lastReadAt: {'ama': DateTime(2026, 10, 20, 12, 5)},
      ).isReadByEveryone(message, 'me'),
      isFalse,
    );
  });

  test('group parses cached Firestore data and current user unread count', () {
    final group = GroupChat.fromMap('group-9', {
      'type': 'group',
      'title': 'Database Geeks',
      'members': ['me', 'ama'],
      'memberProfiles': {'me': _me.toMap(), 'ama': _ama.toMap()},
      'admins': ['me'],
      'createdBy': 'me',
      'lastMessage': 'Indexes are worth it',
      'lastSenderId': 'ama',
      'unread': {'me': 3, 'ama': 0},
      'lastReadAt': {'me': 1700000000000},
      'createdAt': 1690000000000,
    }, myUid: 'me');

    expect(group.title, 'Database Geeks');
    expect(group.memberCount, 2);
    expect(group.isAdmin('me'), isTrue);
    expect(group.profileFor('ama')?.username, 'ama');
    expect(group.visibleUnread, 3);
    expect(group.lastMessageSender, 'ama');
  });

  test('group messages map the sender username onto the bubble', () {
    final message = DirectMessage(
      id: 'm1',
      senderId: 'ama',
      senderName: 'Ama Mensah',
      senderUsername: 'ama',
      text: 'Question 4?',
      type: 'text',
      createdAt: DateTime(2026, 10, 20, 12),
    );

    final ui = message.toUiMessage(
      myUid: 'me',
      isSeen: false,
      showUsername: true,
      sender: _ama,
    );

    expect(ui.senderName, 'ama');
    expect(ui.senderColor, _ama.avatarColor);
    expect(ui.isMe, isFalse);
  });

  testWidgets('persistent group chat shows member count and sender names', (
    WidgetTester tester,
  ) async {
    final group = _group(lastReadAt: {'ama': DateTime(2026, 10, 20, 13)});
    final messages = [
      DirectMessage(
        id: 'm1',
        senderId: 'ama',
        senderName: 'Ama Mensah',
        senderUsername: 'ama',
        text: 'Question 4 is on the drive',
        type: 'text',
        createdAt: DateTime(2026, 10, 20, 12),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PersistentGroupChatScreen(
          chatId: group.id,
          initialGroup: group,
          groupStream: Stream.value(group),
          messagesStream: Stream.value(messages),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('CSC 200 Study Group'), findsAtLeastNWidgets(1));
    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('Group info'), findsOneWidget);
    expect(find.text('Question 4 is on the drive'), findsOneWidget);
    expect(find.text('ama'), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('group-message-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-plus-button')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('group-message-input')),
      'Thanks Ama',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('group-send-button')), findsOneWidget);
  });

  testWidgets('create group requires a name and at least one member', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateGroupScreen(users: Stream.value(const [_ama]))),
    );
    await tester.pumpAndSettle();

    TextButton submit() => tester.widget<TextButton>(
      find.byKey(const ValueKey('create-group-submit')),
    );

    expect(submit().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('create-group-name')),
      'Project Team',
    );
    await tester.pump();
    expect(submit().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('group-member-ama')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('group-selected-ama')), findsOneWidget);
    expect(submit().onPressed, isNotNull);
  });
}
