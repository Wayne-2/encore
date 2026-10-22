import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Compresses recorded and captured media before it is uploaded to R2.
///
/// Voice notes are transcoded to a mono 32 kbps AAC file. That keeps a
/// five-minute note comfortably small while remaining playable everywhere the
/// original `.m4a` was. Story videos are reduced to 720p H.264/AAC.
///
/// Compression is an optimisation: if FFmpeg cannot process a file (an
/// unsupported codec, a missing native library, or a cancelled session), the
/// original path is returned so sending still works.
class MediaCompressor {
  MediaCompressor._();

  static final MediaCompressor instance = MediaCompressor._();

  Future<String> compressVoice(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;

    final output = await _outputPath('voice', '.m4a');
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        sourcePath,
        '-vn',
        '-c:a',
        'aac',
        '-b:a',
        '32k',
        '-ac',
        '1',
        '-ar',
        '22050',
        '-movflags',
        '+faststart',
        output,
      ]);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode) && await File(output).exists()) {
        return output;
      }
    } catch (_) {
      // Fall back to the original recording.
    }
    await _deleteQuietly(output);
    return sourcePath;
  }

  Future<String> compressStoryImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;

    final output = await _outputPath('story', '.jpg');
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        sourcePath,
        '-vf',
        'scale=w=1440:h=2560:force_original_aspect_ratio=decrease',
        '-q:v',
        '3',
        output,
      ]);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode) && await File(output).exists()) {
        return output;
      }
    } catch (_) {
      // Fall back to the original image.
    }
    await _deleteQuietly(output);
    return sourcePath;
  }

  Future<String> compressStoryVideo(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;

    final output = await _outputPath('story', '.mp4');
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        sourcePath,
        '-vf',
        'scale=720:-2',
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '26',
        '-c:a',
        'aac',
        '-b:a',
        '96k',
        '-movflags',
        '+faststart',
        output,
      ]);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode) && await File(output).exists()) {
        return output;
      }
    } catch (_) {
      // Fall back to the original video.
    }
    await _deleteQuietly(output);
    return sourcePath;
  }

  Future<String> _outputPath(String folder, String extension) async {
    final root = Directory(
      '${(await getTemporaryDirectory()).path}/encore_compressed/$folder',
    );
    if (!await root.exists()) await root.create(recursive: true);
    return '${root.path}/media-${DateTime.now().microsecondsSinceEpoch}'
        '$extension';
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort.
    }
  }
}
