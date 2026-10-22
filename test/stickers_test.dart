import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:encore/services/sticker_store.dart';
import 'package:encore/widgets/chat_emoji_picker.dart';

Uint8List _webp(int seed) {
  return Uint8List.fromList([
    0x52,
    0x49,
    0x46,
    0x46,
    0x10,
    0x00,
    0x00,
    0x00,
    0x57,
    0x45,
    0x42,
    0x50,
    0x56,
    0x50,
    0x38,
    0x4C,
    seed,
    seed + 1,
    seed + 2,
    seed + 3,
  ]);
}

Uint8List _validWebp() {
  return base64Decode(
    'UklGRmIAAABXRUJQVlA4IFYAAADwAgCdASoMAAcAAgA0JbACdLoB8gFKA+wCuAAP'
    'QBPAQAD+zgeDPr1Nt++xzMd++pP/lXpu/V9e3k9vx/4zXuAijaP/6TI74hwoeND'
    '/W7C9rod3/GrgAA==',
  );
}

void main() {
  late Directory root;
  late Directory input;

  setUp(() {
    root = Directory.systemTemp.createTempSync('encore_stickers_root_');
    input = Directory.systemTemp.createTempSync('encore_stickers_input_');
    StickerStore.instance.useRootForTesting(root);
  });

  tearDown(() {
    StickerStore.instance.useRootForTesting(null);
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (input.existsSync()) input.deleteSync(recursive: true);
  });

  test('imports webp stickers recursively and skips duplicates', () async {
    final pack = Directory('${input.path}/Pack One')
      ..createSync(recursive: true);
    final nested = Directory('${input.path}/nested')..createSync();
    File('${pack.path}/first.webp').writeAsBytesSync(_webp(1));
    File('${nested.path}/second.WEBP').writeAsBytesSync(_webp(2));
    File('${pack.path}/notes.txt').writeAsStringSync('not a sticker');

    final first = await StickerStore.instance.importDirectory(input.path);
    expect(first.error, isNull);
    expect(first.imported, 2);
    expect(first.skipped, 0);
    expect(StickerStore.instance.items, hasLength(2));
    for (final sticker in StickerStore.instance.items) {
      expect(sticker.path, startsWith(root.path));
      expect(File(sticker.path).existsSync(), isTrue);
    }

    final second = await StickerStore.instance.importDirectory(input.path);
    expect(second.imported, 0);
    expect(second.skipped, 2);
    expect(StickerStore.instance.items, hasLength(2));
  });

  test('rejects files that are not WebP', () async {
    final result = await StickerStore.instance.importSources([
      StickerSource(name: 'fake.webp', bytes: Uint8List.fromList([1, 2, 3])),
    ]);

    expect(result.imported, 0);
    expect(result.error, isNotNull);
    expect(StickerStore.instance.items, isEmpty);
  });

  test('reports an empty folder without adding stickers', () async {
    final result = await StickerStore.instance.importDirectory(input.path);

    expect(result.imported, 0);
    expect(result.error, contains('No .webp stickers'));
    expect(StickerStore.instance.items, isEmpty);
  });

  test('removing a sticker deletes it from the tray and disk', () async {
    File('${input.path}/one.webp').writeAsBytesSync(_webp(9));
    await StickerStore.instance.importDirectory(input.path);
    final sticker = StickerStore.instance.items.single;

    await StickerStore.instance.remove(sticker);

    expect(StickerStore.instance.items, isEmpty);
    expect(File(sticker.path).existsSync(), isFalse);
  });

  testWidgets(
    'imported stickers render in the tray and invoke the send callback',
    (WidgetTester tester) async {
      await tester.runAsync(
        () => StickerStore.instance.importSources([
          StickerSource(name: 'hello.webp', bytes: _validWebp(), pack: 'Test'),
        ]),
      );
      final sticker = StickerStore.instance.items.single;
      StickerItem? sent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatEmojiStickerPanel(
              controller: TextEditingController(),
              onStickerSelected: (item) async => sent = item,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('chat-sticker-tab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(const ValueKey('chat-sticker-grid')), findsOneWidget);
      expect(find.byKey(ValueKey('sticker-${sticker.id}')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('sticker-${sticker.id}')));
      await tester.pump();

      expect(sent?.id, sticker.id);
    },
  );
}
