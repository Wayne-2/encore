import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/models/chat_conversation.dart';
import 'package:encore/models/direct_chat.dart';
import 'package:encore/screens/persistent_direct_chat_screen.dart';
import 'package:encore/services/chat_store.dart';
import 'package:encore/widgets/chat_bubble.dart';

const _peer = ChatUser(
  id: 'peer-1',
  name: 'Ama Mensah',
  username: 'ama',
  level: 'CSC 200',
);

void main() {
  test('direct chat ids are deterministic regardless of member order', () {
    expect(ChatStore.directChatId('zoe', 'ama'), 'dm_ama_zoe');
    expect(ChatStore.directChatId('ama', 'zoe'), 'dm_ama_zoe');
  });

  test('chat user derives its handle and initials', () {
    expect(_peer.handle, '@ama');
    expect(_peer.initials, 'AM');
    expect(
      const ChatUser(id: 'x', name: '', username: 'solo').displayName,
      'solo',
    );
  });

  test('direct chat preview describes media and deleted messages', () {
    final base = DirectChat(
      id: 'dm_ama_zoe',
      peer: _peer,
      members: const ['ama', 'zoe'],
      lastMessage: '',
      lastMessageAt: DateTime(2026, 10, 20, 12),
      lastSenderId: 'zoe',
    );

    expect(
      DirectChat(
        id: base.id,
        peer: base.peer,
        members: base.members,
        lastMessage: '',
        lastMessageAt: base.lastMessageAt,
        lastSenderId: base.lastSenderId,
        lastMessageType: 'image',
      ).preview(myUid: 'ama'),
      'Photo',
    );
    expect(
      DirectChat(
        id: base.id,
        peer: base.peer,
        members: base.members,
        lastMessage: '',
        lastMessageAt: base.lastMessageAt,
        lastSenderId: base.lastSenderId,
        lastMessageType: 'deleted',
      ).preview(myUid: 'ama'),
      'This message was deleted',
    );
    expect(
      DirectChat(
        id: base.id,
        peer: base.peer,
        members: base.members,
        lastMessage: 'Hello',
        lastMessageAt: base.lastMessageAt,
        lastSenderId: 'ama',
      ).preview(myUid: 'ama'),
      'You: Hello',
    );
  });

  test('direct message parses cached Firestore map data', () {
    final message = DirectMessage.fromMap('m1', {
      'senderId': 'ama',
      'senderName': 'Ama Mensah',
      'senderUsername': 'ama',
      'text': 'See you at 4',
      'type': 'text',
      'createdAt': 1700000000000,
      'replyTo': {
        'id': 'm0',
        'senderId': 'zoe',
        'senderName': 'Zoe',
        'text': 'Are we still meeting?',
        'type': 'text',
      },
    });

    expect(message.id, 'm1');
    expect(message.text, 'See you at 4');
    expect(
      message.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    expect(message.replyTo?.text, 'Are we still meeting?');
  });

  testWidgets('persistent chat shows its profile header and input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersistentDirectChatScreen(chatId: 'dm_ama_peer-1', peer: _peer),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Ama Mensah'), findsAtLeastNWidgets(1));
    expect(find.text('@ama'), findsOneWidget);
    expect(find.text('No messages yet. Say hi.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('persistent-message-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('persistent-plus-button')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('persistent-message-input')),
      'Hey Ama',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('persistent-send-button')),
      findsOneWidget,
    );
  });

  testWidgets('persistent chat menu exposes profile and call actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersistentDirectChatScreen(chatId: 'dm_ama_peer-1', peer: _peer),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('persistent-chat-menu')));
    await tester.pumpAndSettle();

    expect(find.text('View profile'), findsAtLeastNWidgets(1));
    expect(find.text('Voice call'), findsOneWidget);
    expect(find.text('Video call'), findsOneWidget);
    expect(find.text('Clear chat'), findsOneWidget);
  });

  testWidgets('chat bubble renders replies, edited state and seen ticks', (
    WidgetTester tester,
  ) async {
    const message = ChatMessage(
      id: 'm1',
      text: 'See you at 4',
      time: '4:00 pm',
      isMe: true,
      isSeen: true,
      isEdited: true,
      replyToSender: 'Ama',
      replyToText: 'Are we still meeting?',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );

    expect(find.text('Ama'), findsOneWidget);
    expect(find.text('Are we still meeting?'), findsOneWidget);
    expect(find.text('edited'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });
}
