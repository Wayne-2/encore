import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/screens/direct_chat_screen.dart';
import 'package:encore/screens/group_chat_screen.dart';
import 'package:encore/screens/home_shell.dart';
import 'package:encore/screens/messages_screen.dart';
import 'package:encore/screens/story_viewer_screen.dart';

void main() {
  testWidgets('MessagesScreen renders Story reel and Conversations list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MessagesScreen()),
      ),
    );

    // Header
    expect(find.text('Messages'), findsOneWidget);

    // Section headings
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);

    // Story usernames
    for (final name in ['_cypher', '_divine', '_wayne', '_encore', '_chris']) {
      expect(find.text(name), findsAtLeastNWidgets(1));
    }

    // Conversation titles
    expect(find.text('SOCAHTOA'), findsOneWidget);
    expect(find.text('OFFICIAL GROUP CSC 200 LVL'), findsOneWidget);
    expect(find.text('_daniel'), findsOneWidget);
    expect(find.text('_james'), findsOneWidget);
    expect(find.text('_lfx'), findsOneWidget);

    // Group sender prefix
    expect(find.textContaining('_cypher:'), findsOneWidget);
  });

  testWidgets('Tapping a story opens the StoryViewerScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MessagesScreen()),
      ),
    );

    // Tap the first story (_cypher)
    await tester.tap(find.text('_cypher').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(StoryViewerScreen), findsOneWidget);
    expect(find.text('45m ago'), findsOneWidget);
    expect(find.text('Reply to _cypher...'), findsOneWidget);
  });

  testWidgets(
    'Tapping a group opens GroupChatScreen with WhatsApp interface & Anonymous mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MessagesScreen()),
        ),
      );

      // Tap official group
      await tester.tap(find.text('OFFICIAL GROUP CSC 200 LVL'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupChatScreen), findsOneWidget);
      expect(find.text('OFFICIAL GROUP CSC 200 LVL'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);

      // Verify paperclip icon exists
      final paperclip = find.byKey(const ValueKey('paperclip-icon'));
      expect(paperclip, findsOneWidget);

      // Tap paperclip icon to open WhatsApp attachment menu
      await tester.tap(paperclip);
      await tester.pumpAndSettle();

      // Verify Anon OFF toggle button exists in the attachment grid
      expect(find.text('Anon OFF'), findsOneWidget);
      final anonGridBtn = find.byKey(const ValueKey('anon-grid-button'));
      expect(anonGridBtn, findsOneWidget);

      // Toggle Anonymous Mode ON via the grid button
      await tester.tap(anonGridBtn);
      await tester.pump();
      expect(find.text('Anon ON'), findsOneWidget);

      // Dismiss the bottom sheet
      Navigator.of(tester.element(anonGridBtn)).pop();
      await tester.pumpAndSettle();

      // Clear any snackbars so they don't obscure bottom elements
      ScaffoldMessenger.of(tester.element(find.byType(GroupChatScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // Verify top-right Anonymous Mode indicator and Turn off action are visible
      expect(find.text('Anonymous'), findsOneWidget);
      expect(find.text('Turn Off'), findsOneWidget);
      expect(find.text('Anonymous...'), findsOneWidget);

      // Type and send an anonymous message
      final input = find.byType(TextField);
      await tester.enterText(input, 'This is a test anonymous assignment question');
      await tester.pumpAndSettle();

      // Tap send button
      await tester.tap(find.byKey(const ValueKey('send-button')));
      await tester.pumpAndSettle();

      // Verify message appears with anonymous notice and no sender ID
      expect(
        find.text('This is a test anonymous assignment question'),
        findsOneWidget,
      );
      expect(
        find.text('Sent anonymously (No sender ID)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Tapping a direct chat opens DirectChatScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MessagesScreen()),
      ),
    );

    // Tap direct chat _daniel
    await tester.tap(find.text('_daniel'));
    await tester.pumpAndSettle();

    expect(find.byType(DirectChatScreen), findsOneWidget);
    expect(find.text('_daniel'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);

    // Send a message
    final input = find.byType(TextField);
    await tester.enterText(input, 'Sent you the receipt bro!');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('direct-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sent you the receipt bro!'), findsOneWidget);
  });

  testWidgets('Navigating to Messages tab from HomeShell displays MessagesScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));

    // Tap Messages in bottom navigation bar
    await tester.tap(find.byKey(const ValueKey('nav-Messages')));
    await tester.pumpAndSettle();

    expect(find.byType(MessagesScreen), findsOneWidget);
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
  });
}
