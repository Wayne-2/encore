import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_type.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

/// A recorded voice note waiting to be uploaded.
class VoiceRecording {
  const VoiceRecording({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  final String path;
  final Duration duration;
  final List<int> waveform;

  int get durationMs => duration.inMilliseconds;
}

class _LiveRecording {
  const _LiveRecording({
    this.duration = Duration.zero,
    this.amplitude = 0,
    this.waveform = const [],
    this.cancelling = false,
  });

  final Duration duration;
  final double amplitude;
  final List<double> waveform;
  final bool cancelling;

  _LiveRecording copyWith({
    Duration? duration,
    double? amplitude,
    List<double>? waveform,
    bool? cancelling,
  }) {
    return _LiveRecording(
      duration: duration ?? this.duration,
      amplitude: amplitude ?? this.amplitude,
      waveform: waveform ?? this.waveform,
      cancelling: cancelling ?? this.cancelling,
    );
  }
}

/// WhatsApp-style press-and-hold microphone button.
///
/// Recording starts on pointer down, tracks the input level for the waveform,
/// and finishes on release. Dragging left past the cancel threshold discards
/// the note instead of sending it.
class HoldToRecordButton extends StatefulWidget {
  const HoldToRecordButton({
    super.key,
    required this.onRecorded,
    required this.onMessage,
    this.enabled = true,
    this.color,
    this.size = 22,
  });

  final Future<void> Function(VoiceRecording recording) onRecorded;
  final ValueChanged<String> onMessage;
  final bool enabled;
  final Color? color;
  final double size;

  @override
  State<HoldToRecordButton> createState() => _HoldToRecordButtonState();
}

class _HoldToRecordButtonState extends State<HoldToRecordButton> {
  static const double _cancelThreshold = 78;
  static const Duration _minimumDuration = Duration(milliseconds: 700);
  static const Duration _maximumDuration = Duration(minutes: 5);

  final ValueNotifier<_LiveRecording> _live = ValueNotifier(
    const _LiveRecording(),
  );

  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  OverlayEntry? _overlay;
  Timer? _ticker;
  Stopwatch? _stopwatch;
  String? _path;

  bool _busy = false;
  bool _recording = false;
  bool _finishing = false;
  bool _cancelRequested = false;
  bool _releaseQueued = false;
  double _startX = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    _hideOverlay();
    unawaited(_amplitudeSubscription?.cancel());
    final recorder = _recorder;
    if (recorder != null) unawaited(recorder.cancel());
    _live.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || !widget.enabled) return;
    _busy = true;
    _releaseQueued = false;
    _cancelRequested = false;

    try {
      final recorder = _recorder ??= AudioRecorder();
      final allowed = await recorder.hasPermission();
      if (!mounted) return;
      if (!allowed) {
        widget.onMessage('Allow microphone access to send voice notes.');
        return;
      }

      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/encore_voice_notes',
      );
      if (!await directory.exists()) await directory.create(recursive: true);
      final path =
          '${directory.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      if (!mounted) {
        await recorder.cancel();
        return;
      }

      _path = path;
      _recording = true;
      _stopwatch = Stopwatch()..start();
      _live.value = const _LiveRecording();
      _amplitudeSubscription = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 90))
          .listen(_onAmplitude);
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _tick();
      });
      _showOverlay();
      setState(() {});
      unawaited(HapticFeedback.mediumImpact());

      if (_releaseQueued) await _finish(cancelled: _cancelRequested);
    } catch (_) {
      if (mounted) widget.onMessage('Could not start recording.');
    } finally {
      if (!_recording) _busy = false;
    }
  }

  void _tick() {
    final stopwatch = _stopwatch;
    if (!_recording || stopwatch == null) return;
    final duration = stopwatch.elapsed;
    _live.value = _live.value.copyWith(duration: duration);
    if (duration >= _maximumDuration) {
      unawaited(_finish());
    }
  }

  void _onAmplitude(Amplitude amplitude) {
    if (!_recording) return;
    final normalized = ((amplitude.current + 48) / 48).clamp(0.04, 1.0);
    final waveform = [..._live.value.waveform, normalized];
    if (waveform.length > 42) waveform.removeAt(0);
    _live.value = _live.value.copyWith(
      amplitude: normalized,
      waveform: List.unmodifiable(waveform),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _startX = event.position.dx;
    unawaited(_start());
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_recording) return;
    final cancelling = (_startX - event.position.dx) >= _cancelThreshold;
    if (cancelling == _cancelRequested) return;
    _cancelRequested = cancelling;
    _live.value = _live.value.copyWith(cancelling: cancelling);
    if (cancelling) unawaited(HapticFeedback.selectionClick());
  }

  void _onPointerUp(PointerUpEvent event) {
    _releaseQueued = true;
    if (!_recording) return;
    unawaited(_finish(cancelled: _cancelRequested));
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _releaseQueued = true;
    if (!_recording) return;
    unawaited(_finish(cancelled: true));
  }

  Future<void> _finish({bool cancelled = false}) async {
    if (!_recording || _finishing) return;
    _finishing = true;
    _ticker?.cancel();
    _ticker = null;
    _stopwatch?.stop();
    final duration = _stopwatch?.elapsed ?? Duration.zero;
    final waveform = _live.value.waveform;
    _stopwatch = null;

    _hideOverlay();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    final recorder = _recorder;
    final recordedPath = _path;
    _path = null;
    _recording = false;
    if (mounted) setState(() {});

    String? savedPath;
    if (recorder != null) {
      try {
        if (cancelled) {
          await recorder.cancel();
        } else {
          savedPath = await recorder.stop();
        }
      } catch (_) {
        savedPath = null;
      }
    }

    final shouldDiscard = cancelled || duration < _minimumDuration;
    if (shouldDiscard) {
      final discardPath = savedPath ?? recordedPath;
      if (discardPath != null) {
        try {
          final file = File(discardPath);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Discarding the temp file is best effort.
        }
      }
      if (!cancelled && mounted) {
        widget.onMessage('Hold the microphone to record a voice note.');
      }
    } else {
      final path = savedPath ?? recordedPath;
      if (path == null) {
        if (mounted) widget.onMessage('Could not save that voice note.');
      } else {
        try {
          await widget.onRecorded(
            VoiceRecording(
              path: path,
              duration: duration,
              waveform: [
                for (final value in waveform)
                  (value * 100).round().clamp(0, 100),
              ],
            ),
          );
        } catch (_) {
          if (mounted) {
            widget.onMessage('Could not send that voice note.');
          }
        }
      }
    }

    _finishing = false;
    _busy = false;
    _releaseQueued = false;
    _cancelRequested = false;
    _live.value = const _LiveRecording();
  }

  void _showOverlay() {
    final overlay = Overlay.of(context, rootOverlay: true);
    _hideOverlay();
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 88,
        child: _RecorderOverlay(live: _live),
      ),
    );
    overlay.insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Hold to record voice note',
      child: Semantics(
        button: true,
        label: 'Hold to record voice note',
        child: Listener(
          onPointerDown: widget.enabled ? _onPointerDown : null,
          onPointerMove: widget.enabled ? _onPointerMove : null,
          onPointerUp: widget.enabled ? _onPointerUp : null,
          onPointerCancel: widget.enabled ? _onPointerCancel : null,
          child: IconButton(
            icon: Icon(
              LucideIcons.mic,
              color: _recording
                  ? SpotifyColors.accent
                  : widget.color ?? scheme.onSurfaceVariant,
              size: widget.size,
            ),
            onPressed: () {},
          ),
        ),
      ),
    );
  }
}

class _RecorderOverlay extends StatefulWidget {
  const _RecorderOverlay({required this.live});

  final ValueNotifier<_LiveRecording> live;

  @override
  State<_RecorderOverlay> createState() => _RecorderOverlayState();
}

class _RecorderOverlayState extends State<_RecorderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<_LiveRecording>(
        valueListenable: widget.live,
        builder: (context, live, _) {
          return Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: SpotifyColors.surface.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: SpotifyColors.borderStrong),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.82, end: 1.12).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: live.cancelling
                            ? SpotifyColors.danger
                            : SpotifyColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    child: Text(
                      _formatDuration(live.duration),
                      style: AppType.timestamp(
                        Theme.of(context).colorScheme,
                      ).copyWith(color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: CustomPaint(
                        painter: _LiveWaveformPainter(
                          values: live.waveform,
                          amplitude: live.amplitude,
                          color: live.cancelling
                              ? SpotifyColors.danger
                              : SpotifyColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    live.cancelling ? LucideIcons.x : LucideIcons.mic,
                    size: 17,
                    color: live.cancelling
                        ? SpotifyColors.danger
                        : SpotifyColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    live.cancelling ? 'Release to cancel' : 'Slide to cancel',
                    style: AppType.timestamp(Theme.of(context).colorScheme)
                        .copyWith(
                          color: live.cancelling
                              ? SpotifyColors.danger
                              : Colors.white70,
                          fontFamily: AppTheme.fontFamily,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _LiveWaveformPainter extends CustomPainter {
  _LiveWaveformPainter({
    required this.values,
    required this.amplitude,
    required this.color,
  });

  final List<double> values;
  final double amplitude;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 2.0;
    final count = math.max(1, (size.width / (barWidth + gap)).floor());
    final paint = Paint()
      ..color = color
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final source = values.isEmpty ? [amplitude] : values;

    for (var index = 0; index < count; index++) {
      final sourceIndex = ((source.length - count + index) % source.length)
          .abs();
      final value = source[sourceIndex].clamp(0.06, 1.0);
      final height = 5 + (size.height - 7) * value;
      final x = index * (barWidth + gap) + barWidth / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWaveformPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color;
  }
}
