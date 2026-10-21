import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:encore/models/trend.dart';
import 'package:encore/screens/trend_image_viewer_screen.dart';
import 'package:encore/screens/trending_more_screen.dart';
import 'package:encore/services/trend_store.dart';

void main() {
  testWidgets('tapping a trend cover opens the full-size image viewer', (
    WidgetTester tester,
  ) async {
    TrendStore.instance.clear();
    final bytes = img.encodePng(img.Image(width: 4, height: 3));
    TrendStore.instance.post(
      title: 'Library hours',
      body: 'The library is now open until 10 PM through the exam period.',
      author: 'Ama Boateng',
      media: [TrendMedia(thumbnail: bytes)],
    );

    await tester.pumpWidget(const MaterialApp(home: TrendingMoreScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trend-feed-cover-0')));
    await tester.pumpAndSettle();

    expect(find.byType(TrendImageViewerScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trend-image-viewer-close')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('trend-image-viewer-close')));
    await tester.pumpAndSettle();

    expect(find.byType(TrendImageViewerScreen), findsNothing);

    TrendStore.instance.clear();
  });
}
