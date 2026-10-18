import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// The app-wide loading indicator.
///
/// A single source of truth for spinners so every loading state matches the
/// splash screen's FadingCube. Pair it with [LoadingOverlay] for whole-page
/// loads, or [ShimmerBox] for inline/skeleton loading.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.size = 22, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SpinKitFadingCube(color: color, size: size);
  }
}
