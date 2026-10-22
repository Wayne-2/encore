import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:encore/services/story_store.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('encore_story_test_');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  test('publishing a story rejects a missing file', () async {
    expect(
      () => StoryStore.instance.publish(
        filePath: '${temp.path}/missing.jpg',
        isVideo: false,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('could not be read'),
        ),
      ),
    );
  });

  test('publishing a story rejects an empty file', () async {
    final file = File('${temp.path}/empty.jpg')..writeAsBytesSync([]);

    expect(
      () => StoryStore.instance.publish(filePath: file.path, isVideo: false),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('empty'),
        ),
      ),
    );
  });

  test(
    'publishing a photo story trims the caption and records the media',
    () async {
      final file = File('${temp.path}/photo.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);

      final story = await StoryStore.instance.publish(
        filePath: file.path,
        isVideo: false,
        caption: '  Campus vibes tonight  ',
      );

      expect(story.id, startsWith('story-local-'));
      expect(story.authorId, 'local');
      expect(story.storyImage, file.path);
      expect(story.isVideo, isFalse);
      expect(story.caption, 'Campus vibes tonight');
      expect(story.createdAt, isNotNull);
    },
  );

  test('publishing a video story keeps the video flag', () async {
    final file = File('${temp.path}/clip.mp4')..writeAsBytesSync([9, 8, 7]);

    final story = await StoryStore.instance.publish(
      filePath: file.path,
      isVideo: true,
      caption: '   ',
    );

    expect(story.isVideo, isTrue);
    expect(story.storyImage, file.path);
    expect(story.caption, isNull);
  });
}
