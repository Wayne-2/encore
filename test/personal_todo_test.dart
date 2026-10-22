import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:encore/screens/personal_todo_screen.dart';
import 'package:encore/screens/profile_screen.dart';
import 'package:encore/services/todo_store.dart';

void main() {
  final store = TodoStore.instance;

  setUp(() async {
    await store.resetForTesting();
    await store.initialize();
  });

  tearDown(() => store.resetForTesting());

  testWidgets('Profile opens personal todo and hides the share button', (
    tester,
  ) async {
    await store.add(
      title: 'Submit lab report',
      dueAt: DateTime.now().subtract(const Duration(hours: 1)),
      alarm: false,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal todo'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-todo-badge')), findsOneWidget);
    expect(find.byIcon(LucideIcons.share2), findsNothing);

    await tester.tap(find.text('Personal todo'));
    await tester.pumpAndSettle();

    expect(find.byType(PersonalTodoScreen), findsOneWidget);
    expect(find.text('Submit lab report'), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-overdue-badge')), findsOneWidget);
  });

  testWidgets('Personal todo adds, completes and clears a task', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PersonalTodoScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No todos yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('todo-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('todo-title-field')),
      'Read chapter 4',
    );
    await tester.tap(find.byKey(const ValueKey('todo-save')));
    await tester.pumpAndSettle();

    expect(find.text('Read chapter 4'), findsOneWidget);
    expect(store.items, hasLength(1));

    final id = store.items.first.id;
    await tester.tap(find.byKey(ValueKey('todo-check-$id')));
    await tester.pumpAndSettle();

    expect(store.completed, hasLength(1));
    expect(find.text('Read chapter 4'), findsOneWidget);

    final clear = find.byKey(const ValueKey('todo-clear-completed'));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(store.items, isEmpty);
    expect(find.text('No todos yet'), findsOneWidget);
  });
}
