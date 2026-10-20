import 'package:flutter/material.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// A centred empty-state placeholder with a gently floating icon above its
/// message. The float runs once when the state appears and then settles, so it
/// stays calm while the user reads the message.
class FloatingEmptyState extends StatefulWidget {
  const FloatingEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  State<FloatingEmptyState> createState() => _FloatingEmptyStateState();
}

class _FloatingEmptyStateState extends State<FloatingEmptyState>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1100);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  )..forward();

  late final Animation<double> _bob = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: -8,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: -8,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 1,
    ),
  ]).animate(_controller);

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _scale = Tween<double>(begin: 0.9, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _bob.value),
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(scale: _scale, child: child),
              ),
            ),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: SpotifyColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: SpotifyColors.accent.withValues(alpha: 0.24),
                ),
              ),
              child: Icon(widget.icon, size: 24, color: SpotifyColors.accent),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: AppType.subtitle(scheme),
          ),
        ],
      ),
    );
  }
}
