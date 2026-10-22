import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:encore/models/chat_conversation.dart';
import 'package:encore/models/direct_chat.dart';
import 'package:encore/screens/persistent_direct_chat_screen.dart';
import 'package:encore/services/chat_store.dart';
import 'package:encore/services/sticker_store.dart';
import 'package:encore/theme/spotify_colors.dart';
import 'package:encore/widgets/chat_bubble.dart';
import 'package:encore/widgets/voice_note_player.dart';

const _peer = ChatUser(
  id: 'peer-1',
  name: 'Ama Mensah',
  username: 'ama',
  level: 'CSC 200',
  department: 'Computer Science',
  faculty: 'SICT',
);

const _privatePeer = ChatUser(
  id: 'peer-2',
  name: 'Yaw Private',
  username: 'yaw',
  level: 'CSC 300',
  department: 'Computer Science',
  faculty: 'SICT',
  privacyMode: true,
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
        lastMessageType: 'voice',
      ).preview(myUid: 'ama'),
      'Voice note',
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

  test('sticker messages parse and preview as stickers', () {
    final message = DirectMessage.fromMap('sticker-1', {
      'senderId': 'ama',
      'senderName': 'Ama Mensah',
      'senderUsername': 'ama',
      'text': '',
      'type': 'sticker',
      'stickerUrl': 'https://media.example.com/sticker.webp',
      'createdAt': 1700000000000,
    });

    expect(message.stickerUrl, 'https://media.example.com/sticker.webp');
    expect(message.toReplyPreview().preview, 'Sticker');
    expect(
      message.toUiMessage(myUid: 'zoe', isSeen: false).stickerUrl,
      'https://media.example.com/sticker.webp',
    );

    final chat = DirectChat(
      id: 'dm_ama_zoe',
      peer: _peer,
      members: const ['ama', 'zoe'],
      lastMessage: '',
      lastMessageAt: DateTime(2026, 10, 20, 12),
      lastSenderId: 'ama',
      lastMessageType: 'sticker',
    );
    expect(chat.preview(myUid: 'zoe'), 'Sticker');
  });

  test('a cleared DM stays hidden until a newer message arrives', () {
    final cleared = DirectChat(
      id: 'dm_ama_zoe',
      peer: _peer,
      members: const ['ama', 'zoe'],
      lastMessage: 'Old message',
      lastMessageAt: DateTime(2026, 10, 20, 12),
      lastSenderId: 'zoe',
      clearedAt: DateTime(2026, 10, 20, 13),
    );
    final fresh = DirectChat(
      id: cleared.id,
      peer: cleared.peer,
      members: cleared.members,
      lastMessage: 'New message',
      lastMessageAt: DateTime(2026, 10, 20, 14),
      lastSenderId: 'zoe',
      clearedAt: cleared.clearedAt,
    );

    expect(cleared.isCleared, isTrue);
    expect(cleared.preview(myUid: 'ama'), 'No messages yet');
    expect(fresh.isCleared, isFalse);
    expect(fresh.preview(myUid: 'ama'), 'New message');
  });

  test('deleted messages drop their replied-to preview', () {
    final message = DirectMessage.fromMap('m2', {
      'senderId': 'ama',
      'senderName': 'Ama Mensah',
      'senderUsername': 'ama',
      'text': '',
      'type': 'deleted',
      'deleted': true,
      'createdAt': 1700000000000,
      'replyTo': {
        'id': 'm0',
        'senderId': 'zoe',
        'senderName': 'Zoe',
        'text': 'Are we still meeting?',
        'type': 'text',
      },
    });

    final ui = message.toUiMessage(myUid: 'zoe', isSeen: false);

    expect(message.deleted, isTrue);
    expect(message.replyTo, isNull);
    expect(ui.text, 'This message was deleted');
    expect(ui.replyToText, isNull);
    expect(ui.replyToSender, isNull);
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

  testWidgets('chat profile sheet shows full name and academic details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersistentDirectChatScreen(chatId: 'dm_ama_peer-1', peer: _peer),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('View profile').first);
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('chat-profile-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Ama Mensah')),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(of: sheet, matching: find.text('@ama')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Computer Science')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('CSC 200')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('SICT')),
      findsOneWidget,
    );
  });

  testWidgets('private chat profile sheet only reveals the username', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersistentDirectChatScreen(
          chatId: 'dm_yaw_peer-2',
          peer: _privatePeer,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('View profile').first);
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('chat-profile-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('@yaw')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Yaw Private')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Department')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Level')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Faculty')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('This profile is private'),
      ),
      findsOneWidget,
    );
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
    expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
  });

  testWidgets('pending messages show a clock instead of sent ticks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessage(
              id: 'pending',
              text: 'Queued while offline',
              time: '4:00 pm',
              isMe: true,
              isSeen: false,
              isPending: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.clock), findsOneWidget);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
    expect(find.byIcon(LucideIcons.check), findsNothing);
  });

  test('queued messages keep a local timestamp until the server confirms', () {
    final message = DirectMessage.fromMap('pending', {
      'senderId': 'zoe',
      'senderName': 'Zoe',
      'senderUsername': 'zoe',
      'text': 'Queued while offline',
      'type': 'text',
      'createdAt': null,
      'localCreatedAt': DateTime(2026, 10, 21, 16),
    }, pending: true);

    expect(message.pending, isTrue);
    expect(message.createdAt, DateTime(2026, 10, 21, 16));
    expect(message.toUiMessage(myUid: 'zoe', isSeen: false).isPending, isTrue);
  });

  testWidgets('emoji button inserts a pick into the composer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersistentDirectChatScreen(chatId: 'dm_ama_peer-1', peer: _peer),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('persistent-emoji-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-emoji-picker')), findsOneWidget);

    await tester.tap(find.text('Smileys'));
    await tester.pumpAndSettle();

    final inputFinder = find.byKey(const ValueKey('persistent-message-input'));
    final panel = find.byKey(const ValueKey('chat-emoji-picker'));
    expect(inputFinder, findsOneWidget);
    expect(panel, findsOneWidget);

    // The tray sits below the composer instead of covering it.
    final inputRect = tester.getRect(
      find.byKey(const ValueKey('persistent-emoji-button')),
    );
    final panelRect = tester.getRect(panel);
    expect(panelRect.top, greaterThanOrEqualTo(inputRect.bottom - 1));

    await tester.tap(find.byKey(const ValueKey('emoji-😀')));
    await tester.pump();

    final input = tester.widget<TextField>(inputFinder);
    expect(input.controller?.text, contains('😀'));
    expect(panel, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('persistent-emoji-button')));
    await tester.pump();
    expect(panel, findsNothing);
  });

  testWidgets('sticker tab shows the import empty state', (
    WidgetTester tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('encore_stickers_test_');
    StickerStore.instance.useRootForTesting(root);
    addTearDown(() {
      StickerStore.instance.useRootForTesting(null);
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: PersistentDirectChatScreen(chatId: 'dm_ama_peer-1', peer: _peer),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('persistent-emoji-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-sticker-tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-sticker-empty')), findsOneWidget);
    expect(find.text('No stickers yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-sticker-import')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-sticker-files')), findsOneWidget);
  });

  testWidgets('swiping a bubble triggers reply in both directions', (
    WidgetTester tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatBubble(
                message: const ChatMessage(
                  id: 'in',
                  text: 'Incoming',
                  time: '4:00 pm',
                ),
                onReply: () => replies++,
              ),
              ChatBubble(
                message: const ChatMessage(
                  id: 'out',
                  text: 'Outgoing',
                  time: '4:01 pm',
                  isMe: true,
                ),
                onReply: () => replies++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.text('Incoming'), const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);

    await tester.drag(find.text('Outgoing'), const Offset(-90, 0));
    await tester.pumpAndSettle();
    expect(replies, 2);
  });

  testWidgets('outgoing bubbles use the muted green chat colour', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessage(
              id: 'out',
              text: 'Outgoing',
              time: '4:01 pm',
              isMe: true,
            ),
          ),
        ),
      ),
    );

    final colours = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color);
    expect(colours, contains(SpotifyColors.chatOutgoing));
  });

  testWidgets('voice messages render an inline waveform player', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessage(
              id: 'voice',
              text: '',
              time: '4:02 pm',
              isMe: true,
              voiceUrl: 'https://media.example.com/voice.m4a',
              voiceDurationMs: 4000,
              voiceWaveform: [20, 60, 35, 90, 45],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(VoiceNotePlayer), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
  });

  testWidgets('deleted bubble only shows the inactive placeholder', (
    WidgetTester tester,
  ) async {
    const message = ChatMessage(
      id: 'm2',
      text: 'This message was deleted',
      time: '4:00 pm',
      isMe: true,
      isSeen: true,
      isEdited: true,
      isDeleted: true,
      replyToSender: 'Ama',
      replyToText: 'Are we still meeting?',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );

    expect(find.text('This message was deleted'), findsOneWidget);
    expect(find.text('Ama'), findsNothing);
    expect(find.text('Are we still meeting?'), findsNothing);
    expect(find.text('edited'), findsNothing);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
  });
}
