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
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );

    // Header
    expect(find.text('Messages'), findsOneWidget);

    // Section heading
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
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
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
        const MaterialApp(home: Scaffold(body: MessagesScreen())),
      );

      // Tap official group
      await tester.tap(find.text('OFFICIAL GROUP CSC 200 LVL'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupChatScreen), findsOneWidget);
      expect(find.text('OFFICIAL GROUP CSC 200 LVL'), findsAtLeastNWidgets(1));
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);

      // Verify paperclip icon exists
      final paperclip = find.byKey(const ValueKey('paperclip-icon'));
      expect(paperclip, findsOneWidget);

      // Tap paperclip icon to open WhatsApp attachment menu
      await tester.tap(paperclip);
      await tester.pumpAndSettle();

      // Verify attachment items in plus menu: Document, Camera, Audio (NO anon toggle)
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Anon OFF'), findsNothing);

      // Dismiss the bottom sheet
      Navigator.of(tester.element(find.text('Document'))).pop();
      await tester.pumpAndSettle();

      // Open three dots menu at top to toggle Anonymous Mode
      await tester.tap(find.byKey(const ValueKey('chat-three-dots-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Voice Call'), findsOneWidget);
      expect(find.text('Video Call'), findsOneWidget);
      expect(find.text('Enter Anonymous Mode'), findsOneWidget);

      await tester.tap(find.text('Enter Anonymous Mode'));
      await tester.pumpAndSettle();

      // Clear any snackbars so they don't obscure bottom elements
      ScaffoldMessenger.of(
        tester.element(find.byType(GroupChatScreen)),
      ).clearSnackBars();
      await tester.pumpAndSettle();

      // Verify top-right Anonymous Mode indicator and Turn off action are visible
      expect(find.text('Anonymous'), findsOneWidget);
      expect(find.text('Turn Off'), findsOneWidget);
      expect(find.text('Anonymous...'), findsOneWidget);

      // Type and send an anonymous message
      final input = find.byType(TextField);
      await tester.enterText(
        input,
        'This is a test anonymous assignment question',
      );
      await tester.pumpAndSettle();

      // Tap send button
      await tester.tap(find.byKey(const ValueKey('send-button')));
      await tester.pumpAndSettle();

      // Verify message appears with anonymous notice and no sender ID
      expect(
        find.text('This is a test anonymous assignment question'),
        findsOneWidget,
      );
      expect(find.text('Sent anonymously (No sender ID)'), findsOneWidget);
    },
  );

  testWidgets('Tapping a direct chat opens DirectChatScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );

    // Tap direct chat _daniel
    await tester.tap(find.text('_daniel'));
    await tester.pumpAndSettle();

    expect(find.byType(DirectChatScreen), findsOneWidget);
    expect(find.textContaining('_daniel'), findsAtLeastNWidgets(1));
    expect(find.text('TODAY'), findsOneWidget);

    // Send a message
    final input = find.byType(TextField);
    await tester.enterText(input, 'Sent you the receipt bro!');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('direct-send-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sent you the receipt bro!'), findsOneWidget);
  });

  testWidgets(
    'Wayne direct chat matches reference layout, three-dots actions, and plus menu',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MessagesScreen())),
      );

      // Scroll to and tap _wayne in conversations list
      await tester.ensureVisible(find.text('_wayne').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('_wayne').last);
      await tester.pumpAndSettle();

      expect(find.byType(DirectChatScreen), findsOneWidget);

      // Profile header elements matching reference image
      expect(find.text('Joined 11 August 2023'), findsOneWidget);
      expect(find.text('View profile'), findsOneWidget);
      expect(find.text('Good evening chief'), findsOneWidget);
      expect(find.text('Seen'), findsOneWidget);
      expect(find.text('Nice one 😀'), findsOneWidget);

      // Bottom input has only plus button and input pill
      expect(find.byKey(const ValueKey('plus-button')), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      // Verify NO separate video or phone icons in the top bar actions
      expect(find.byIcon(Icons.videocam_outlined), findsNothing);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);

      // Open three dots menu at the top
      await tester.tap(find.byKey(const ValueKey('chat-three-dots-menu')));
      await tester.pumpAndSettle();

      // Verify Call, Video Call, and Anonymous Mode toggle are inside the three dots menu
      expect(find.text('Voice Call'), findsOneWidget);
      expect(find.text('Video Call'), findsOneWidget);
      expect(find.text('Enter Anonymous Mode'), findsOneWidget);

      // Toggle anonymous mode from three dots
      await tester.tap(find.text('Enter Anonymous Mode'));
      await tester.pumpAndSettle();

      // Clear snackbars so they don't obscure bottom elements
      ScaffoldMessenger.of(
        tester.element(find.byType(DirectChatScreen)),
      ).clearSnackBars();
      await tester.pumpAndSettle();

      // Top right status pill and input placeholder appear
      expect(find.text('Anonymous'), findsOneWidget);
      expect(find.text('Turn Off'), findsOneWidget);
      expect(find.text('Anonymous...'), findsOneWidget);

      // Open plus attachment sheet
      await tester.tap(find.byKey(const ValueKey('plus-button')));
      await tester.pumpAndSettle();

      // Verify attachment items
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Anon ON'), findsNothing);
      expect(find.text('Anon OFF'), findsNothing);

      // Verify rotation is 0.125 (45 degrees, turning + into X)
      final rotationFinder = find.byType(AnimatedRotation);
      expect(rotationFinder, findsOneWidget);
      expect(tester.widget<AnimatedRotation>(rotationFinder).turns, 0.125);

      // Tap the button again (or tap outside) to close the menu and animate back to +
      await tester.tap(
        find.byKey(const ValueKey('plus-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Verify menu closed and rotated back to 0 degrees (+)
      expect(find.text('Document'), findsNothing);
      expect(tester.widget<AnimatedRotation>(rotationFinder).turns, 0.0);
    },
  );

  testWidgets(
    'Navigating to Messages tab from HomeShell displays MessagesScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeShell()));

      // Tap Messages in bottom navigation bar
      await tester.tap(find.byKey(const ValueKey('nav-Messages')));
      await tester.pumpAndSettle();

      expect(find.byType(MessagesScreen), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
    },
  );
}
