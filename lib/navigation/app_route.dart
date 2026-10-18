import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../theme/spotify_colors.dart';

/// A Material "shared axis" (horizontal) page route for screens that have a
/// navigational relationship — e.g. welcome -> sign up, log in <-> sign up.
///
/// Built with the pre-built [SharedAxisTransition] from the `animations`
/// package. [fillColor] is set explicitly so the transition never falls back
/// to a light default behind the outgoing page.
Route<T> sharedAxisRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: SpotifyColors.background,
        child: child,
      );
    },
  );
}

/// A simple cross-fade route, used for the splash-style loading screens.
Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
