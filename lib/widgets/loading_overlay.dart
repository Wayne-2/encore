import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_type.dart';
import 'app_loader.dart';

/// Covers [child] with a dark, blurred scrim and the shared [AppLoader] while
/// [isLoading] is true.
///
/// Use for whole-page loading states so any blocking load looks the same
/// everywhere:
///
/// ```dart
/// LoadingOverlay(
///   isLoading: _busy,
///   message: 'Saving…',
///   child: Scaffold(...),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLoader(),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(message!, style: AppType.subtitle(scheme)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
