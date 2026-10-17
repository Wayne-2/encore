import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  /// Logo + wordmark fade in (0 → 45%).
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
  );

  /// Loading spinner fade-in (75% → 100%), then it keeps spinning.
  late final Animation<double> _spinnerIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
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
          Navigator.of(context).pushReplacement(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(milliseconds: 450),
              pageBuilder: (_, _, _) => const WelcomeScreen(),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
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
            // Logo mark + wordmark fade in together.
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
                    'Encore',
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
