import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../navigation/app_route.dart';
import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';
import 'home_shell.dart';

/// Final loading screen shown after the profile-picture step.
///
/// Mirrors the launch splash screen — same dark backdrop, logo fade-in and
/// spinning indicator — but reads "Getting you ready" while the account is
/// prepared, then hands off to the [HomeShell].
class GettingReadyScreen extends StatefulWidget {
  const GettingReadyScreen({super.key});

  @override
  State<GettingReadyScreen> createState() => _GettingReadyScreenState();
}

class _GettingReadyScreenState extends State<GettingReadyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  /// Logo + label fade in (0 → 60%).
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
  );

  /// Loading spinner fade-in (50% → 100%), then it keeps spinning.
  late final Animation<double> _spinnerIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
  );

  static const double _logoSize = 104;
  static const double _spinnerSize = 22;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Hold on the finished lockup + spinner before revealing the app.
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushReplacement(fadeRoute<void>(const HomeShell()));
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlackColors.darkBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo mark + label fade in together.
            FadeTransition(
              opacity: _fadeIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(_fadeIn),
                    child: Image.asset(
                      'assets/Encore.png',
                      width: _logoSize,
                      height: _logoSize,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Getting you ready',
                    textAlign: TextAlign.center,
                    style: AppTheme.splashWordmarkStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Small FadingCube spinner — fades in and keeps spinning.
            FadeTransition(
              opacity: _spinnerIn,
              child: SpinKitFadingCube(color: Colors.white, size: _spinnerSize),
            ),
          ],
        ),
      ),
    );
  }
}
