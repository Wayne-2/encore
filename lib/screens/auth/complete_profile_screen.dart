import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/account_options.dart';
import '../../data/departments.dart';
import '../../navigation/app_route.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/spotify_colors.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/auth_dialog.dart';
import '../../widgets/loading_overlay.dart';
import '../getting_ready_screen.dart';
import '../welcome_screen.dart';
import 'auth_field.dart';
import 'auth_scaffold.dart';
import 'auth_top_bar.dart';

/// Lets a verified account finish onboarding after an interrupted sign-up.
///
/// It is reached from the splash screen, the login screen and the email
/// verification screen, so no account with a missing or half-written profile
/// can enter the app. Existing checkpoints are pre-filled; the affected user
/// can also type the details from scratch.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _regNumber = TextEditingController();
  final _adminId = TextEditingController();

  String? _department;
  String? _role;
  String? _level;

  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email.text = AuthService.instance.currentUser?.email ?? '';
    _loadProfile();
  }

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _username.dispose();
    _regNumber.dispose();
    _adminId.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!AuthService.isAvailable) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted && !_loading) setState(() => _loading = true);

    Map<String, dynamic>? data;
    var failed = false;
    try {
      data = await AuthService.instance.currentUserProfile(
        fallbackToCache: false,
      );
    } catch (_) {
      failed = true;
      data = await AuthService.instance.cachedProfile();
    }

    if (!mounted) return;
    if (data != null) _applyProfile(data);
    setState(() {
      _loading = false;
      _loadFailed = failed && data == null;
    });
  }

  void _applyProfile(Map<String, dynamic> data) {
    String? read(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final fullName = read('fullName');
    if (fullName != null) _fullName.text = fullName;

    final username = read('username');
    if (username != null) {
      _username.text = username.replaceFirst(RegExp(r'^_+'), '');
    }

    final registrationNumber = read('registrationNumber');
    if (registrationNumber != null) _regNumber.text = registrationNumber;

    final department = read('department');
    if (department != null) {
      final normalized = normalizeDepartment(department);
      if (kDepartments.contains(normalized)) _department = normalized;
    }

    final role = read('role')?.toLowerCase();
    if (role == kStudentRole.toLowerCase()) {
      _role = kStudentRole;
    } else if (role == kAdminRole.toLowerCase()) {
      _role = kAdminRole;
    }

    final level = read('level');
    if (level != null && kLevels.contains(level)) _level = level;

    final adminId = read('adminId');
    if (adminId != null) _adminId.text = adminId;

    final email = read('email');
    if (email != null) _email.text = email;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!AuthService.isAvailable) return;

    final user = AuthService.instance.currentUser;
    if (user == null) {
      await _logOut();
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.instance.saveUserDetails(
        uid: user.uid,
        fullName: _fullName.text.trim(),
        username: '_${_username.text.trim().toLowerCase()}',
        email: _email.text.trim(),
        registrationNumber: _regNumber.text.trim(),
        department: _department ?? '',
        faculty: kFaculty,
        role: _role ?? '',
        level: _level,
        adminId: _role == kAdminRole ? _adminId.text.trim() : null,
        merge: true,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showAuthDialog(
        context,
        title: 'Couldn’t save your details',
        message: error.message ?? 'Please try again in a moment.',
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showAuthDialog(
        context,
        title: 'Something went wrong',
        message: 'Please try again in a moment.',
      );
      return;
    }

    await SessionService.instance.markLoggedIn();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(
      context,
    ).pushReplacement(fadeRoute<void>(const GettingReadyScreen()));
  }

  Future<void> _logOut() async {
    await SessionService.instance.endSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute<void>(const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: LoadingOverlay(
        isLoading: _busy,
        message: 'Saving your details…',
        child: _loading
            ? const Center(child: AppLoader())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AuthTopBar(title: 'Finish your profile'),
                      const SizedBox(height: 24),
                      Text('Almost there', style: AuthScaffold.titleStyle),
                      const SizedBox(height: 8),
                      Text(
                        'Complete the details below to finish setting up your '
                        'account.',
                        style: AuthScaffold.subtitleStyle,
                      ),
                      if (_loadFailed) ...[
                        const SizedBox(height: 16),
                        _LoadFailedBanner(onRetry: _loadProfile),
                      ],
                      const SizedBox(height: 28),
                      AuthField(
                        label: 'Email',
                        icon: 'email',
                        controller: _email,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      AuthField(
                        label: 'Username',
                        controller: _username,
                        prefixText: '_',
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          _LowerCaseFormatter(),
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-z0-9_]'),
                          ),
                        ],
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Choose a username';
                          if (value.length < 3) {
                            return 'Use at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AuthField(
                        label: 'Registration Number',
                        icon: 'registration_number',
                        controller: _regNumber,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return 'Enter your registration number';
                          }
                          if (value.length != 11) {
                            return 'Registration number must be 11 digits';
                          }
                          if (!value.startsWith('202')) {
                            return 'Registration number must start with 202';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('complete-department-dropdown'),
                        initialValue: _department,
                        onChanged: (value) =>
                            setState(() => _department = value),
                        isExpanded: true,
                        dropdownColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Department',
                        ),
                        items: [
                          for (final department in kDepartments)
                            DropdownMenuItem(
                              value: department,
                              child: Text(department),
                            ),
                        ],
                        validator: (v) =>
                            v == null ? 'Select your department' : null,
                      ),
                      const SizedBox(height: 16),
                      const AuthField(
                        label: 'Faculty',
                        icon: 'faculty',
                        initialValue: kFaculty,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('complete-role-dropdown'),
                        initialValue: _role,
                        onChanged: (value) => setState(() => _role = value),
                        isExpanded: true,
                        dropdownColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(hintText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: kStudentRole,
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: kAdminRole,
                            child: Text('Admin'),
                          ),
                        ],
                        validator: (v) => v == null ? 'Select a role' : null,
                      ),
                      if (_role != null) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('complete-level-dropdown'),
                          initialValue: _level,
                          onChanged: (value) => setState(() => _level = value),
                          isExpanded: true,
                          dropdownColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: const InputDecoration(hintText: 'Level'),
                          items: [
                            for (final level in kLevels)
                              DropdownMenuItem(
                                value: level,
                                child: Text(level),
                              ),
                          ],
                          validator: (v) =>
                              v == null ? 'Select your level' : null,
                        ),
                      ],
                      if (_role == kAdminRole) ...[
                        const SizedBox(height: 16),
                        AuthField(
                          label: 'Admin ID',
                          icon: 'registration_number',
                          controller: _adminId,
                          textInputAction: TextInputAction.done,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your admin ID'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _busy ? null : _save,
                          child: const Text('Finish setup'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _busy ? null : _logOut,
                          style: TextButton.styleFrom(
                            foregroundColor: SpotifyColors.accent,
                            textStyle: AuthScaffold.linkStyle,
                          ),
                          child: const Text('Log out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _LoadFailedBanner extends StatelessWidget {
  const _LoadFailedBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Couldn’t load your saved details. Fill them in below or retry.',
            style: AuthScaffold.subtitleStyle,
          ),
        ),
        TextButton(
          key: const ValueKey('complete-profile-retry'),
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lower = newValue.text.toLowerCase();
    if (lower == newValue.text) return newValue;
    return newValue.copyWith(text: lower);
  }
}
