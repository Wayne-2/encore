import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/models/direct_chat.dart';
import 'package:encore/models/group_chat.dart';
import 'package:encore/screens/group_settings_screen.dart';
import 'package:encore/screens/persistent_group_chat_screen.dart';

const _me = ChatUser(id: 'me', name: 'Wayne Doe', username: 'wayne');
const _ama = ChatUser(id: 'ama', name: 'Ama Mensah', username: 'ama');
const _kofi = ChatUser(id: 'kofi', name: 'Kofi Boateng', username: 'kofi');

GroupChat _group({
  bool anonymousMessagesEnabled = false,
  bool membersCanPost = true,
  bool membersCanAddMembers = true,
  bool lastSenderAnonymous = false,
}) {
  return GroupChat(
    id: 'group-1',
    title: 'CSC 200 Study Group',
    members: const ['me', 'ama', 'kofi'],
    memberProfiles: const {'me': _me, 'ama': _ama, 'kofi': _kofi},
    adminIds: const ['me'],
    createdBy: 'me',
    description: 'Past questions, labs and exam prep.',
    anonymousMessagesEnabled: anonymousMessagesEnabled,
    membersCanPost: membersCanPost,
    membersCanAddMembers: membersCanAddMembers,
    lastMessage: 'Question 4 is on the drive',
    lastSenderId: 'ama',
    lastSenderAnonymous: lastSenderAnonymous,
    lastMessageAt: DateTime(2026, 10, 20, 12),
    createdAt: DateTime(2026, 10, 19, 9),
  );
}

void main() {
  test('group parses permissions and masks anonymous preview senders', () {
    final group = GroupChat.fromMap('group-9', {
      'type': 'group',
      'title': 'Quiet Group',
      'members': ['me', 'ama'],
      'memberProfiles': {'me': _me.toMap(), 'ama': _ama.toMap()},
      'admins': ['me'],
      'createdBy': 'me',
      'description': 'Announcements only',
      'anonymousMessagesEnabled': true,
      'membersCanPost': false,
      'membersCanAddMembers': false,
      'lastMessage': 'Secret update',
      'lastSenderId': 'ama',
      'lastSenderAnonymous': true,
      'unread': {'me': 1, 'ama': 0},
    }, myUid: 'me');

    expect(group.description, 'Announcements only');
    expect(group.anonymousMessagesEnabled, isTrue);
    expect(group.membersCanPost, isFalse);
    expect(group.membersCanAddMembers, isFalse);
    expect(group.canPost('me'), isTrue);
    expect(group.canPost('ama'), isFalse);
    expect(group.lastMessageSender, 'Anonymous Sender');
  });

  test('anonymous messages hide identity from bubbles and replies', () {
    final message = DirectMessage.fromMap('m1', {
      'senderId': 'ama',
      'senderName': 'Ama Mensah',
      'senderUsername': 'ama',
      'anonymous': true,
      'text': 'The mock paper is out',
      'type': 'text',
      'createdAt': 1700000000000,
    });

    final ui = message.toUiMessage(
      myUid: 'me',
      isSeen: false,
      showUsername: true,
      senderIsAdmin: true,
      sender: _ama,
    );

    expect(message.senderLabel, 'Anonymous Sender');
    expect(message.toReplyPreview().senderName, 'Anonymous Sender');
    expect(ui.isAnonymous, isTrue);
    expect(ui.senderName, 'Anonymous Sender');
    expect(ui.senderColor, isNull);
    expect(ui.isAdmin, isFalse);
  });

  testWidgets('group settings exposes admin controls and member actions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const group = GroupChat(
      id: 'group-1',
      title: 'CSC 200 Study Group',
      members: ['me', 'ama', 'kofi'],
      memberProfiles: {'me': _me, 'ama': _ama, 'kofi': _kofi},
      adminIds: ['me'],
      createdBy: 'me',
      description: 'Past questions, labs and exam prep.',
      anonymousMessagesEnabled: true,
      membersCanPost: false,
      membersCanAddMembers: false,
      lastMessage: 'Question 4 is on the drive',
      lastSenderId: 'ama',
      lastMessageAt: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GroupSettingsScreen(
          chatId: group.id,
          initialGroup: group,
          groupStream: Stream.value(group),
          usersStream: Stream.value(const [_ama, _kofi]),
          myUid: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Group settings'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('group-settings-anonymous')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('group-settings-post')),
          )
          .value,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('group-settings-add-members')),
      findsOneWidget,
    );
    expect(find.text('Admin'), findsAtLeastNWidgets(1));
    expect(find.text('Past questions, labs and exam prep.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-setting-member-ama')));
    await tester.pumpAndSettle();
    expect(find.text('Make group admin'), findsOneWidget);
    expect(find.text('Remove from group'), findsOneWidget);
  });

  testWidgets('non-admins see locked settings and no add button', (
    WidgetTester tester,
  ) async {
    const group = GroupChat(
      id: 'group-1',
      title: 'CSC 200 Study Group',
      members: ['me', 'ama'],
      memberProfiles: {'me': _me, 'ama': _ama},
      adminIds: ['me'],
      membersCanAddMembers: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GroupSettingsScreen(
          chatId: group.id,
          initialGroup: group,
          groupStream: Stream.value(group),
          usersStream: Stream.value(const [_me]),
          myUid: 'ama',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('group-settings-anonymous')),
          )
          .onChanged,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('group-settings-add-members')),
      findsNothing,
    );
    expect(find.text('Only admins can change these settings'), findsOneWidget);
  });

  testWidgets('group info offers group settings', (WidgetTester tester) async {
    final group = _group();
    await tester.pumpWidget(
      MaterialApp(
        home: PersistentGroupChatScreen(
          chatId: group.id,
          initialGroup: group,
          groupStream: Stream.value(group),
          messagesStream: Stream.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Group info').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('group-settings-option')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-settings-option')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('group-settings-screen')), findsOneWidget);
  });

  testWidgets('anonymous toggle appears in the group composer', (
    WidgetTester tester,
  ) async {
    final group = _group(anonymousMessagesEnabled: true);
    await tester.pumpWidget(
      MaterialApp(
        home: PersistentGroupChatScreen(
          chatId: group.id,
          initialGroup: group,
          groupStream: Stream.value(group),
          messagesStream: Stream.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('group-anonymous-toggle')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('group-anonymous-toggle')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('group-anonymous-banner')),
      findsOneWidget,
    );
    expect(find.text('Send anonymously…'), findsOneWidget);
  });

  testWidgets('announcement-only groups lock the composer for members', (
    WidgetTester tester,
  ) async {
    final group = _group(membersCanPost: false);
    await tester.pumpWidget(
      MaterialApp(
        home: PersistentGroupChatScreen(
          chatId: group.id,
          initialGroup: group,
          groupStream: Stream.value(group),
          messagesStream: Stream.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('group-posting-locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-message-input')), findsNothing);
  });
}
