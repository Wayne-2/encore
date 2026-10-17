import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../navigation/app_route.dart';
import '../../theme/slack_colors.dart';
import '../getting_ready_screen.dart';
import 'auth_field.dart';
import 'auth_scaffold.dart';
import 'login_screen.dart';

/// Create an Encore account (four steps).
///
/// Step 1 — personal details (full name, username, email, password).
/// Step 2 — school details (registration number, department, faculty, role).
/// Step 3 — email verification (a confirmation link is sent to the email).
/// Step 4 — profile picture.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  /// Total number of steps, mirrored by the progress ribbons up top.
  static const int _stepCount = 4;

  /// Heading shown in the top bar for each step.
  static const List<String> _stepTitles = [
    'Create your account',
    'School details',
    'Verify your email',
    'Add a profile picture',
  ];

  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  // Step 1 — personal details.
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Step 2 — school details.
  final _regNumber = TextEditingController();
  final _department = TextEditingController();
  final _faculty = TextEditingController();
  final _adminId = TextEditingController();
  String? _role;
  String? _level;

  /// Selected roles.
  static const String _studentRole = 'Student';
  static const String _adminRole = 'Admin';

  /// Enrolled levels offered to students.
  static const List<String> _levels = [
    '100 Level',
    '200 Level',
    '300 Level',
    '400 Level',
    '500 Level',
    'Extras',
    'Alumni',
  ];

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _regNumber.dispose();
    _department.dispose();
    _faculty.dispose();
    _adminId.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _step++);
    }
  }

  /// Returns to the previous step, or leaves the flow from the first step.
  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _step--);
    }
  }

  void _finish() {
    // TODO(auth): persist the account before continuing.
    _continueToLoading();
  }

  void _skipPhoto() {
    // TODO(auth): continue into the app without a profile picture.
    _continueToLoading();
  }

  /// Leaves the sign-up flow for the final loading screen.
  void _continueToLoading() {
    Navigator.of(
      context,
    ).pushReplacement(fadeRoute<void>(const GettingReadyScreen()));
  }

  void _pickPhoto() {
    // TODO(auth): let the user choose an image (add an image picker).
  }

  void _resendEmail() {
    // TODO(auth): resend the verification email.
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepHeader(title: _stepTitles[_step], onBack: _goBack),
            const SizedBox(height: 24),
            _StepIndicator(step: _step, count: _stepCount),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: PageTransitionSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder:
                    (child, primaryAnimation, secondaryAnimation) {
                      return SharedAxisTransition(
                        animation: primaryAnimation,
                        secondaryAnimation: secondaryAnimation,
                        transitionType: SharedAxisTransitionType.vertical,
                        fillColor: SlackColors.darkBackground,
                        child: child,
                      );
                    },
                child: switch (_step) {
                  0 => _buildPersonalDetails(context),
                  1 => _buildSchoolDetails(context),
                  2 => _buildVerification(context),
                  _ => _buildProfilePicture(context),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 1 — personal details
  // -------------------------------------------------------------------------
  Widget _buildPersonalDetails(BuildContext context) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Please fill in your personal details to continue',
          style: AuthScaffold.subtitleStyle,
        ),
        const SizedBox(height: 28),
        AuthField(
          label: 'Full Name',
          icon: 'name',
          controller: _fullName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
        ),
        const SizedBox(height: 16),
        AuthField(
          label: 'Username',
          controller: _username,
          prefixText: '@',
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Choose a username' : null,
        ),
        const SizedBox(height: 16),
        AuthField(
          label: 'Email',
          icon: 'email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your email';
            final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
            return ok ? null : 'Enter a valid email';
          },
        ),
        const SizedBox(height: 16),
        AuthField(
          label: 'Password',
          icon: 'password',
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          validator: (v) {
            if (v == null || v.isEmpty) return 'Choose a password';
            if (v.length < 6) return 'Use at least 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(onPressed: _next, child: const Text('Continue')),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: AuthScaffold.subtitleStyle,
            ),
            GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).pushReplacement(sharedAxisRoute<void>(const LoginScreen())),
              child: Text('Log in', style: AuthScaffold.linkStyle),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Step 2 — school details
  // -------------------------------------------------------------------------
  Widget _buildSchoolDetails(BuildContext context) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Please fill in your school details to continue',
          style: AuthScaffold.subtitleStyle,
        ),
        const SizedBox(height: 28),
        AuthField(
          label: 'Registration Number',
          icon: 'registration_number',
          controller: _regNumber,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Enter your registration number'
              : null,
        ),
        const SizedBox(height: 16),
        AuthField(
          label: 'Department',
          icon: 'department',
          controller: _department,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your department' : null,
        ),
        const SizedBox(height: 16),
        AuthField(
          label: 'Faculty',
          icon: 'faculty',
          controller: _faculty,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your faculty' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _role,
          onChanged: (value) => setState(() => _role = value),
          isExpanded: true,
          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: const InputDecoration(hintText: 'Role'),
          items: const [
            DropdownMenuItem(value: _studentRole, child: Text('Student')),
            DropdownMenuItem(value: _adminRole, child: Text('Admin')),
          ],
          validator: (v) => v == null ? 'Select a role' : null,
        ),
        // Role-specific follow-up: admins prove their ID, students pick a level.
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: switch (_role) {
            _adminRole => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AuthField(
                label: 'Admin ID',
                icon: 'registration_number',
                controller: _adminId,
                textInputAction: TextInputAction.done,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your admin ID'
                    : null,
              ),
            ),
            _studentRole => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: DropdownButtonFormField<String>(
                initialValue: _level,
                onChanged: (value) => setState(() => _level = value),
                isExpanded: true,
                dropdownColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(hintText: 'Level'),
                items: [
                  for (final level in _levels)
                    DropdownMenuItem(value: level, child: Text(level)),
                ],
                validator: (v) => v == null ? 'Select your level' : null,
              ),
            ),
            _ => const SizedBox(width: double.infinity),
          },
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _next,
            child: const Text('Create Account'),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Step 3 — email verification
  // -------------------------------------------------------------------------
  Widget _buildVerification(BuildContext context) {
    final theme = Theme.of(context);
    final email = _email.text.trim();

    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We sent a verification link to '
          '${email.isEmpty ? 'your email' : email}. '
          'Open it to confirm your account.',
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
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Didn’t get the email? Check your spam folder.',
            textAlign: TextAlign.center,
            style: AuthScaffold.subtitleStyle,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _resendEmail,
            style: TextButton.styleFrom(
              foregroundColor: SlackColors.accentGreen,
              textStyle: AuthScaffold.linkStyle,
            ),
            child: const Text('Resend email'),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(onPressed: _next, child: const Text('Continue')),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Step 4 — profile picture
  // -------------------------------------------------------------------------
  Widget _buildProfilePicture(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the camera icon to add a photo. You can change it later.',
          style: AuthScaffold.subtitleStyle,
        ),
        const SizedBox(height: 32),
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                child: Icon(
                  Icons.person_outline,
                  size: 52,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: SlackColors.accentGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _pickPhoto,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(onPressed: _finish, child: const Text('Finish')),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _skipPhoto,
            style: TextButton.styleFrom(
              foregroundColor: SlackColors.accentGreen,
              textStyle: AuthScaffold.linkStyle,
            ),
            child: const Text('Skip for now'),
          ),
        ),
      ],
    );
  }
}

/// Top bar for the create-account flow: a return arrow plus the step heading,
/// replacing the branded logo/wordmark used elsewhere.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            iconSize: 22,
            color: Colors.white,
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AuthScaffold.titleStyle)),
      ],
    );
  }
}

/// A slim multi-step progress indicator.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: i <= step
                    ? SlackColors.accentGreen
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
