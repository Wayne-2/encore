import 'package:encore/models/chat_conversation.dart';
import 'package:encore/models/direct_chat.dart';
import 'package:encore/screens/library_screen.dart';
import 'package:encore/services/library_store.dart';
import 'package:encore/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    LibraryStore.instance.resetForTests();
  });

  testWidgets('long press opens the chat picker for a public document', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('library-material-demo-csc200-notes')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send in a chat'), findsOneWidget);

    await tester.tap(find.text('Send in a chat'));
    await tester.pumpAndSettle();

    expect(find.text('Send to a chat'), findsOneWidget);
    expect(find.text('No chats yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a shared library message renders as a document card', (
    WidgetTester tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: const ChatMessage(
              id: 'm1',
              text: '',
              time: '10:00 am',
              libraryId: 'doc-1',
              libraryTitle: 'Physics Notes',
              librarySubject: 'PHY 101',
            ),
            onOpenLibrary: () => opened++,
          ),
        ),
      ),
    );

    expect(find.text('Physics Notes'), findsOneWidget);
    expect(find.text('PHY 101'), findsOneWidget);
    expect(find.text('Encore Library · Tap to open'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-library-m1')));
    await tester.pump();

    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  test('a shared document appears in the chat list preview', () {
    final chat = DirectChat(
      id: 'direct-1',
      peer: const ChatUser(id: 'peer', name: 'Ada', username: 'ada'),
      members: const ['me', 'peer'],
      lastMessage: 'Physics Notes',
      lastMessageType: 'library',
      lastMessageAt: DateTime(2026, 1, 1),
      lastSenderId: 'peer',
    );

    expect(chat.preview(myUid: 'me'), 'Document: Physics Notes');
  });
}
