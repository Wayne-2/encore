import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:encore/models/story.dart';
import 'package:encore/screens/story_viewer_screen.dart';

StoryItem _story(String id, String username) {
  return StoryItem(
    id: id,
    authorId: 'author-$id',
    username: username,
    storyImage: 'assets/background.jpeg',
    time: 'Just now',
    createdAt: DateTime(2026, 10, 22, 12),
  );
}

Widget _viewer(List<StoryItem> stories) {
  return MaterialApp(home: StoryViewerScreen(stories: stories));
}

void main() {
  testWidgets('tapping left and right moves between stories', (
    WidgetTester tester,
  ) async {
    final stories = [_story('one', '_alice'), _story('two', '_bob')];
    await tester.pumpWidget(_viewer(stories));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tapAt(const Offset(700, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('_bob'), findsOneWidget);

    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('_alice'), findsOneWidget);
  });

  testWidgets('holding the story pauses playback until release', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_viewer([_story('one', '_alice')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byIcon(LucideIcons.play), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.byIcon(LucideIcons.play), findsNothing);
  });

  testWidgets('tapping an emoji floats it upward and fades it out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_viewer([_story('one', '_alice')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('❤️'));
    await tester.pump();

    expect(find.byKey(const ValueKey('story-reaction-0')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(find.byKey(const ValueKey('story-reaction-0')), findsNothing);
  });

  testWidgets('sending a text reply requires a signed-in chat session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_viewer([_story('one', '_alice')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'Nice story');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('story-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sign in to reply to stories.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Nice story',
    );
  });
}
