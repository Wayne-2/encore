import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/widgets/user_avatar.dart';

void main() {
  test('initials strip leading username underscores', () {
    expect(initialsForName('_wayne'), 'W');
    expect(initialsForName('_odeh solomon'), 'OS');
    expect(initialsForName(''), '?');
  });

  testWidgets('user avatar falls back to initials with a 4px radius', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: UserAvatar(name: 'Odeh Solomon', size: 40)),
    );

    expect(find.text('OS'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(4));
  });
}
