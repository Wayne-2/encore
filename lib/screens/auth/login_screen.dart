import 'package:flutter/material.dart';

import '../../navigation/app_route.dart';
import '../../theme/slack_colors.dart';
import '../home_shell.dart';
import 'auth_field.dart';
import 'auth_scaffold.dart';
import 'auth_top_bar.dart';
import 'create_account_screen.dart';

/// Log in to Encore.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _regNumber = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _regNumber.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO(auth): hook up authentication.
      Navigator.of(context).pushReplacement(fadeRoute<void>(const HomeShell()));
    }
  }

  void _forgotPassword() {
    // TODO(auth): start the password reset flow.
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: SingleChildScrollView(
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
                label: 'Full Name',
                icon: 'name',
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 20),
              AuthField(
                label: 'Registration Number',
                icon: 'registration_number',
                controller: _regNumber,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your registration number'
                    : null,
              ),
              const SizedBox(height: 20),
              AuthField(
                label: 'Password',
                icon: 'password',
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: SlackColors.accentGreen,
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
                    onTap: () => Navigator.of(
                      context,
                    ).push(sharedAxisRoute<void>(const CreateAccountScreen())),
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
    );
  }
}
