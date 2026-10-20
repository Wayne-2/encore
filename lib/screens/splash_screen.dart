import 'package:flutter/material.dart';

import '../navigation/app_route.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import '../widgets/app_loader.dart';
import 'home_shell.dart';
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

  /// Resolved while the logo animates: a valid 24-hour session skips the
  /// welcome/auth flow and opens the Updates tab directly.
  late final Future<bool> _hasSession = _checkSession();

  Future<bool> _checkSession() async {
    try {
      return await SessionService.instance.hasValidSession();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Hold on the finished lockup + spinner before revealing the app.
        Future.delayed(const Duration(milliseconds: 1200), () async {
          final signedIn = await _hasSession;
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            fadeRoute<void>(
              signedIn ? const HomeShell() : const WelcomeScreen(),
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
      backgroundColor: SpotifyColors.background,
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
            // Shared app loader — fades in and keeps spinning.
            FadeTransition(opacity: _spinnerIn, child: const AppLoader()),
          ],
        ),
      ),
    );
  }
}
