import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../navigation/app_route.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/spotify_colors.dart';
import '../../widgets/auth_dialog.dart';
import '../../widgets/loading_overlay.dart';
import '../home_shell.dart';
import 'auth_field.dart';
import 'auth_scaffold.dart';
import 'auth_top_bar.dart';
import 'complete_profile_screen.dart';
import 'create_account_screen.dart';
import 'verify_email_screen.dart';

/// Log in to Encore.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _adminId = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _adminId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Without Firebase (e.g. widget tests) keep the pre-auth behaviour.
    if (!AuthService.isAvailable) {
      Navigator.of(context).pushReplacement(fadeRoute<void>(const HomeShell()));
      return;
    }

    setState(() => _submitting = true);
    try {
      await AuthService.instance.signIn(
        email: _email.text.trim(),
        password: _password.text,
        adminId: _adminId.text,
      );

      // Credentials are valid, but the account may still be mid-onboarding.
      // Route to the exact step that is missing instead of opening an empty
      // profile inside the home shell.
      if (!await AuthService.instance.isEmailVerified()) {
        if (!mounted) return;
        setState(() => _submitting = false);
        Navigator.of(
          context,
        ).pushReplacement(sharedAxisRoute<void>(const VerifyEmailScreen()));
        return;
      }

      final profile = await AuthService.instance.currentUserProfile();
      if (!mounted) return;
      if (!AuthService.isProfileComplete(profile)) {
        setState(() => _submitting = false);
        Navigator.of(
          context,
        ).pushReplacement(sharedAxisRoute<void>(const CompleteProfileScreen()));
        return;
      }

      await SessionService.instance.markLoggedIn();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(fadeRoute<void>(const HomeShell()));
    } on AdminIdException {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showAuthDialog(
        context,
        title: 'Incorrect admin ID',
        message:
            'That admin ID doesn’t match this account. Leave it blank to log '
            'in as a normal user.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showAuthDialog(
        context,
        title: 'Couldn’t log in',
        message: AuthService.messageFor(error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showAuthDialog(
        context,
        title: 'Something went wrong',
        message: 'Please try again in a moment.',
      );
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      await showAuthDialog(
        context,
        title: 'Enter your email',
        message:
            'Type your email above, then tap “Forgot password?” again and '
            'we’ll send you a reset link.',
      );
      return;
    }

    // Without Firebase there is nothing to send.
    if (!AuthService.isAvailable) return;

    setState(() => _submitting = true);
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (!mounted) return;
      setState(() => _submitting = false);
      await showAuthDialog(
        context,
        title: 'Check your inbox',
        message: 'We sent a password reset link to $email.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showAuthDialog(
        context,
        title: 'Couldn’t send the link',
        message: AuthService.messageFor(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: LoadingOverlay(
        isLoading: _submitting,
        message: 'Logging you in…',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthTopBar(title: 'Encore'),
                const SizedBox(height: 24),
                Text('Welcome back', style: AuthScaffold.titleStyle),
                const SizedBox(height: 8),
                Text(
                  'Log in to continue to Encore.',
                  style: AuthScaffold.subtitleStyle,
                ),
                const SizedBox(height: 32),
                AuthField(
                  label: 'Email',
                  icon: 'email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your email';
                    }
                    final ok = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(v.trim());
                    return ok ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 20),
                AuthField(
                  label: 'Password',
                  icon: 'password',
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 20),
                AuthField(
                  label: 'Admin ID',
                  hint: 'Admin ID (optional)',
                  icon: 'registration_number',
                  controller: _adminId,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: SpotifyColors.accent,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: AuthScaffold.linkStyle,
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Log In'),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New here? ', style: AuthScaffold.subtitleStyle),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        sharedAxisRoute<void>(const CreateAccountScreen()),
                      ),
                      child: Text(
                        'Create an account',
                        style: AuthScaffold.linkStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
