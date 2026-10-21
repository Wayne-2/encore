import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:encore/screens/library_screen.dart';
import 'package:encore/services/library_store.dart';

void main() {
  setUp(() {
    LibraryStore.instance.resetForTests();
  });

  testWidgets('library shows the saved list and public material', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your lists'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Reading history'), findsOneWidget);
    expect(find.text('Saved lists'), findsNothing);
    expect(find.text('Digest'), findsNothing);
    expect(find.byKey(const ValueKey('library-new-list')), findsNothing);
    expect(find.byKey(const ValueKey('library-promo')), findsNothing);
    expect(find.text('Saved list'), findsOneWidget);
    expect(find.text('0 materials'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-upload')), findsOneWidget);
    expect(find.text('Public library'), findsOneWidget);
    expect(
      find.textContaining('Document uploads from the Encore community'),
      findsOneWidget,
    );
    expect(
      find.text('Data Structures & Algorithms Lecture Notes'),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.fileText), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library tabs switch between empty highlights and history', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('library-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('No highlights yet'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('library-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing read yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a document starts the reader and records progress', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Data Structures & Algorithms Lecture Notes').first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-preview-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-reader')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('library-reading-progress')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('library-preview-text')), findsOneWidget);
    expect(find.textContaining('Stacks and queues'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-continue')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('library-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-tab-2')));
    await tester.pumpAndSettle();
    expect(
      find.text('Data Structures & Algorithms Lecture Notes'),
      findsOneWidget,
    );
    expect(find.textContaining('% read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters public documents by title and subject', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'calculus',
    );
    await tester.pumpAndSettle();

    expect(find.text('MTH 101 Calculus Problem Set'), findsOneWidget);
    expect(
      find.text('Data Structures & Algorithms Lecture Notes'),
      findsNothing,
    );
    expect(find.text('1 result'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'no such document',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved highlights appear in the Highlights tab', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await LibraryStore.instance.addHighlight(
      materialId: 'demo-csc200-notes',
      materialTitle: 'Data Structures & Algorithms Lecture Notes',
      text: 'A stack follows last in, first out.',
    );

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('library-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('A stack follows last in, first out.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a material fills the Saved list sheet', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('library-material-save-demo-csc200-notes')),
    );
    await tester.pumpAndSettle();
    expect(LibraryStore.instance.isSaved('demo-csc200-notes'), isTrue);
    expect(find.text('1 material'), findsOneWidget);

    await tester.tap(find.text('Saved list'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Data Structures & Algorithms Lecture Notes'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
