import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../theme/spotify_colors.dart';

/// WhatsApp-style horizontal swipe-to-reply wrapper.
///
/// Incoming messages swipe right; outgoing messages swipe left. Once the
/// gesture passes the threshold the bubble springs back and [onReply] fires.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.fromMe,
    required this.onReply,
    this.enabled = true,
  });

  final Widget child;
  final bool fromMe;
  final VoidCallback onReply;
  final bool enabled;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  static const double _threshold = 54;
  static const double _maxDrag = 76;

  double _offset = 0;
  bool _dragging = false;

  double _clamp(double value) {
    if (widget.fromMe) {
      return value.clamp(-_maxDrag, 0);
    }
    return value.clamp(0, _maxDrag);
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() => _offset = _clamp(_offset + details.delta.dx));
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final triggered = _offset.abs() >= _threshold;
    setState(() {
      _dragging = false;
      _offset = 0;
    });
    if (triggered) {
      HapticFeedback.mediumImpact();
      widget.onReply();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final progress = (_offset.abs() / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () {
        if (!mounted) return;
        setState(() {
          _dragging = false;
          _offset = 0;
        });
      },
      child: Stack(
        alignment: widget.fromMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Positioned(
            left: widget.fromMe ? null : 8,
            right: widget.fromMe ? 8 : null,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.7 + progress * 0.3,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: SpotifyColors.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.reply,
                      size: 19,
                      color: SpotifyColors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
