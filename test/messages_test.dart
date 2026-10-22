import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:encore/models/contact_request.dart';
import 'package:encore/models/direct_chat.dart';
import 'package:encore/screens/direct_chat_screen.dart';
import 'package:encore/screens/group_chat_screen.dart';
import 'package:encore/screens/home_shell.dart';
import 'package:encore/screens/messages_screen.dart';
import 'package:encore/screens/add_story_screen.dart';
import 'package:encore/screens/story_viewer_screen.dart';

void main() {
  testWidgets('Messages add button shows incoming request alerts', (
    WidgetTester tester,
  ) async {
    const me = ChatUser(id: 'me', name: 'Me', username: 'me');
    const peer = ChatUser(id: 'peer', name: 'Ama', username: 'ama');
    final request = ContactRequest(
      id: 'request-1',
      fromUid: peer.id,
      toUid: me.id,
      participants: const ['peer', 'me'],
      fromUser: peer,
      toUser: me,
      status: ContactRequestStatus.pending,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesScreen(
            viewerId: me.id,
            requestStream: Stream.value([request]),
          ),
        ),
      ),
    );
    await tester.pump();

    final badge = find.byKey(const ValueKey('compose-badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
  });

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

    // Conversation titles (the list is lazy, so scroll each into view)
    final conversationScrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    ).first;
    for (final entry in {
      'chat-socahtoa': 'SOCAHTOA',
      'chat-official-group': 'OFFICIAL GROUP CSC 200 LVL',
      'chat-daniel': '_daniel',
      'chat-james': '_james',
      'chat-lfx': '_lfx',
    }.entries) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('conversation-${entry.key}')),
        120,
        scrollable: conversationScrollable,
      );
      expect(find.text(entry.value), findsOneWidget);
    }

    // Group sender prefix
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('conversation-chat-socahtoa')),
      -120,
      scrollable: conversationScrollable,
    );
    expect(find.textContaining('_cypher:'), findsOneWidget);
  });

  testWidgets('Your Story opens the Snapchat-style composer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );

    await tester.tap(find.byKey(const ValueKey('add-story-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AddStoryScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('story-shutter')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-gallery')), findsOneWidget);
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
    expect(find.textContaining('45 min'), findsOneWidget);
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
      expect(find.text('Anonymous Sender'), findsAtLeastNWidgets(1));
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
      final conversationScrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('conversation-chat-wayne')),
        120,
        scrollable: conversationScrollable,
      );
      await tester.tap(find.byKey(const ValueKey('conversation-chat-wayne')));
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
      expect(find.byIcon(LucideIcons.mic), findsOneWidget);

      // Verify NO separate video or phone icons in the top bar actions
      expect(find.byIcon(LucideIcons.video), findsNothing);
      expect(find.byIcon(LucideIcons.phone), findsNothing);

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

  testWidgets('Conversation search expands and filters the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );

    expect(
      find.byKey(const ValueKey('conversations-search-open')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('conversations-search-field')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('conversations-search-open')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('conversations-search-field')),
      findsOneWidget,
    );
    expect(find.text('Conversations'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('conversations-search-field')),
      'SOCAHTOA',
    );
    await tester.pumpAndSettle();

    expect(find.text('SOCAHTOA'), findsNWidgets(2));
    expect(find.text('OFFICIAL GROUP CSC 200 LVL'), findsNothing);
    expect(find.text('_daniel'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('conversations-search-close')));
    await tester.pumpAndSettle();

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('OFFICIAL GROUP CSC 200 LVL'), findsOneWidget);
    expect(find.text('_daniel'), findsOneWidget);
  });

  testWidgets('Empty conversation search fills the remaining space', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );

    await tester.tap(find.byKey(const ValueKey('conversations-search-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversations-search-field')),
      'no such conversation',
    );
    await tester.pumpAndSettle();

    final empty = find.byKey(const ValueKey('messages-empty'));
    expect(empty, findsOneWidget);
    expect(
      find.text('No conversations match “no such conversation”.'),
      findsOneWidget,
    );
    expect(tester.getCenter(empty).dy, greaterThan(450));
    expect(
      find.descendant(of: empty, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
  });

  testWidgets('Conversation overflow menu exposes Archive and settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );

    await tester.tap(find.byKey(const ValueKey('conversations-more')));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Message settings'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(
      find.text('Archived conversations are coming soon.'),
      findsOneWidget,
    );
  });

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
