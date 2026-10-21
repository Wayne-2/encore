import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/chat_media_cache.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// Inline WhatsApp-style playback for a voice message.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.url,
    required this.durationMs,
    required this.waveform,
    this.isMe = false,
  });

  final String url;
  final int durationMs;
  final List<int> waveform;
  final bool isMe;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  static final Set<_VoiceNotePlayerState> _instances = {};

  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  bool _preparing = false;
  bool _unavailable = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _speed = 1;

  Duration get _totalDuration {
    final value = _duration ?? Duration(milliseconds: widget.durationMs);
    return value <= Duration.zero ? const Duration(seconds: 1) : value;
  }

  double get _progress {
    final total = _totalDuration.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0, 1);
  }

  @override
  void initState() {
    super.initState();
    _instances.add(this);
  }

  @override
  void dispose() {
    _instances.remove(this);
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_preparing) return;
    final player = _player;
    if (player != null) {
      if (_playing) {
        await player.pause();
      } else {
        if (_position >= _totalDuration) {
          await player.seek(Duration.zero);
        }
        unawaited(player.play());
      }
      return;
    }
    await _prepareAndPlay();
  }

  Future<void> _prepareAndPlay() async {
    setState(() {
      _preparing = true;
      _unavailable = false;
    });
    try {
      final file = await ChatMediaCache.instance.ensureDownloaded(widget.url);
      if (file == null) {
        if (mounted) {
          setState(() {
            _preparing = false;
            _unavailable = true;
          });
        }
        return;
      }

      for (final instance in _instances) {
        if (instance != this) await instance._pauseForOther();
      }

      final player = AudioPlayer();
      _player = player;
      _positionSubscription = player.positionStream.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      });
      _stateSubscription = player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing =
              state.playing &&
              state.processingState != ProcessingState.completed;
          if (state.processingState == ProcessingState.completed) {
            _position = Duration.zero;
          }
        });
      });
      final duration = await player.setFilePath(file.path);
      if (!mounted) return;
      if (duration != null && duration > Duration.zero) {
        _duration = duration;
      }
      await player.setSpeed(_speed);
      setState(() => _preparing = false);
      unawaited(player.play());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _unavailable = true;
      });
    }
  }

  Future<void> _pauseForOther() async {
    if (_playing) await _player?.pause();
  }

  Future<void> _seekTo(double fraction) async {
    final player = _player;
    if (player == null) return;
    final target = Duration(
      milliseconds: (_totalDuration.inMilliseconds * fraction).round(),
    );
    await player.seek(target);
    if (mounted) setState(() => _position = target);
  }

  Future<void> _cycleSpeed() async {
    final next = switch (_speed) {
      1 => 1.5,
      1.5 => 2.0,
      _ => 1.0,
    };
    setState(() => _speed = next);
    await _player?.setSpeed(next);
  }

  @override
  Widget build(BuildContext context) {
    final playedColor = widget.isMe ? Colors.white : SpotifyColors.accent;
    final unplayedColor = Colors.white.withValues(alpha: 0.35);
    final displayed = _playing || _position > Duration.zero
        ? _position
        : _totalDuration;

    return SizedBox(
      width: 238,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 22,
              tooltip: _playing ? 'Pause voice note' : 'Play voice note',
              onPressed: _toggle,
              icon: _preparing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : Icon(
                      _unavailable
                          ? LucideIcons.download
                          : _playing
                          ? LucideIcons.pause
                          : LucideIcons.play,
                      color: Colors.white,
                    ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (_player == null) return;
                    unawaited(
                      _seekTo((details.localPosition.dx / width).clamp(0, 1)),
                    );
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_player == null) return;
                    unawaited(
                      _seekTo((details.localPosition.dx / width).clamp(0, 1)),
                    );
                  },
                  child: SizedBox(
                    height: 32,
                    child: CustomPaint(
                      painter: _VoiceWaveformPainter(
                        values: widget.waveform,
                        progress: _progress,
                        playedColor: playedColor,
                        unplayedColor: unplayedColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatDuration(displayed),
            style: AppType.timestamp(
              Theme.of(context).colorScheme,
            ).copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                _speed == 1 ? '1x' : '${_speed}x',
                style: AppType.timestamp(
                  Theme.of(context).colorScheme,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  _VoiceWaveformPainter({
    required this.values,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  final List<int> values;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.4;
    const gap = 2.0;
    final count = math.max(1, (size.width / (barWidth + gap)).floor());
    final paint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final fallback = _fallbackWaveform(count);

    for (var index = 0; index < count; index++) {
      final value = values.isEmpty
          ? fallback[index]
          : values[(index * values.length / count).floor()].clamp(8, 100);
      final height = 4 + (size.height - 6) * (value / 100);
      final x = index * (barWidth + gap) + barWidth / 2;
      paint.color = index / count <= progress ? playedColor : unplayedColor;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  List<int> _fallbackWaveform(int count) {
    const pattern = [32, 54, 78, 45, 88, 62, 38, 70, 95, 52, 80, 42];
    return [
      for (var index = 0; index < count; index++)
        pattern[index % pattern.length],
    ];
  }

  @override
  bool shouldRepaint(_VoiceWaveformPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor;
  }
}
