import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../navigation/app_route.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/spotify_colors.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/auth_dialog.dart';
import '../../widgets/loading_overlay.dart';
import '../home_shell.dart';
import '../welcome_screen.dart';
import 'auth_scaffold.dart';
import 'auth_top_bar.dart';
import 'complete_profile_screen.dart';

/// Shown when a saved Firebase session has not confirmed its email yet.
///
/// The account stays signed in while the user opens their inbox, so verifying
/// from the mail app and returning resumes exactly here. Only a confirmed
/// email can continue to profile completion or the home shell.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  bool _busy = false;
  bool _navigating = false;

  String get _email => AuthService.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startWatch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  /// Polls Firebase so verification done in another app is picked up without
  /// the user having to press anything.
  void _startWatch() {
    _timer?.cancel();
    if (!AuthService.isAvailable) return;
    _check();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  Future<void> _check() async {
    if (_checking || _navigating) return;
    _checking = true;
    try {
      if (!await AuthService.instance.isEmailVerified()) return;
      await _proceed();
    } finally {
      _checking = false;
    }
  }

  /// Routes to profile completion when onboarding was interrupted, otherwise
  /// starts a fresh session and opens the app.
  Future<void> _proceed() async {
    if (_navigating || !mounted) return;
    _navigating = true;
    _timer?.cancel();

    Map<String, dynamic>? profile;
    try {
      profile = await AuthService.instance.currentUserProfile();
    } catch (_) {
      // Treated as incomplete below; the completion screen can retry.
    }
    if (!mounted) return;

    if (!AuthService.isProfileComplete(profile)) {
      Navigator.of(
        context,
      ).pushReplacement(sharedAxisRoute<void>(const CompleteProfileScreen()));
      return;
    }

    await SessionService.instance.markLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute<void>(const HomeShell()));
  }

  Future<void> _resend() async {
    if (!AuthService.isAvailable) return;

    setState(() => _busy = true);
    try {
      await AuthService.instance.sendVerificationEmail();
      if (!mounted) return;
      _showSnack('Verification email sent');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      await showAuthDialog(
        context,
        title: 'Couldn’t resend the link',
        message: AuthService.messageFor(error),
      );
    } catch (_) {
      if (!mounted) return;
      await showAuthDialog(
        context,
        title: 'Couldn’t resend the link',
        message: 'Please try again in a moment.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useDifferentAccount() async {
    _timer?.cancel();
    await SessionService.instance.endSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute<void>(const WelcomeScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _email;

    return AuthScaffold(
      body: LoadingOverlay(
        isLoading: _busy,
        message: 'Sending…',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthTopBar(title: 'Verify your email'),
              const SizedBox(height: 24),
              Text('One last step', style: AuthScaffold.titleStyle),
              const SizedBox(height: 8),
              Text(
                'We sent a verification link to '
                '${email.isEmpty ? 'your email' : email}. Open it to confirm '
                'your account, then come back here.',
                style: AuthScaffold.subtitleStyle,
              ),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/icons/email.svg',
                    width: 40,
                    height: 40,
                    colorFilter: ColorFilter.mode(
                      theme.colorScheme.onSurfaceVariant,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLoader(size: 16),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Waiting for you to verify your email…',
                      style: AuthScaffold.subtitleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Didn’t get the email? Check your spam folder.',
                  textAlign: TextAlign.center,
                  style: AuthScaffold.subtitleStyle,
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _resend,
                  style: TextButton.styleFrom(
                    foregroundColor: SpotifyColors.accent,
                    textStyle: AuthScaffold.linkStyle,
                  ),
                  child: const Text('Resend email'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _check,
                  child: const Text('I’ve verified my email'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _useDifferentAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: SpotifyColors.accent,
                    textStyle: AuthScaffold.linkStyle,
                  ),
                  child: const Text('Use a different account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
