import 'dart:async';

import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../navigation/app_route.dart';
import '../../services/auth_service.dart';
import '../../services/media_storage.dart';
import '../../services/notification_service.dart';
import '../../theme/spotify_colors.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/auth_dialog.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/shimmer.dart';
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

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with WidgetsBindingObserver {
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

  // Step 4 — profile picture.
  final _media = MediaStorage(workerUrl: AppConfig.r2WorkerUrl);
  Uint8List? _avatarBytes;
  String? _avatarUrl;
  bool _uploading = false;
  bool _uploadFailed = false;

  /// Blocks the flow with the shared [LoadingOverlay] while an auth/database
  /// request is in flight.
  bool _busy = false;
  String? _busyLabel;

  /// Whether the Firebase account has already been created, so stepping back
  /// and forward again does not attempt to re-register the same email.
  bool _registered = false;

  /// Step 3 — email verification. Polled while the user is on that step.
  bool _emailVerified = false;
  Timer? _verifyTimer;

  /// Whether the verification step may be left.
  ///
  /// Tests run without Firebase, so they fall back to the pre-auth behaviour.
  bool get _verificationComplete => !AuthService.isAvailable || _emailVerified;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verifyTimer?.cancel();
    _username.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _regNumber.dispose();
    _department.dispose();
    _faculty.dispose();
    _adminId.dispose();
    _media.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Leaving the school-details step registers the account with Firebase
    // (holding the entered details in state) before the verification step.
    if (_step == 1) {
      if (_registered) {
        _enterVerificationStep();
        return;
      }
      final registered = await _register();
      if (registered && mounted) {
        _registered = true;
        _enterVerificationStep();
      }
      return;
    }

    setState(() => _step++);
  }

  /// Moves to the verification step and starts watching for confirmation.
  void _enterVerificationStep() {
    setState(() => _step = 2);
    _startVerificationWatch();
  }

  /// Returns to the previous step, or leaves the flow from the first step.
  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      _verifyTimer?.cancel();
      setState(() => _step--);
    }
  }

  /// Polls the signed-in user's `emailVerified` flag while the verification
  /// step is open. On iOS/Android the user usually leaves for their mail app,
  /// so [didChangeAppLifecycleState] also re-checks on resume.
  void _startVerificationWatch() {
    _verifyTimer?.cancel();
    if (!AuthService.isAvailable) return;
    _checkVerified();
    _verifyTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerified(),
    );
  }

  Future<void> _checkVerified() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } catch (_) {
      return;
    }
    if (!mounted || _emailVerified) return;
    if (user.emailVerified) {
      _verifyTimer?.cancel();
      setState(() => _emailVerified = true);
      _showVerifiedSnackBar();
    }
  }

  void _showVerifiedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Email verified — you’re all set.')),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == 2) {
      _checkVerified();
    }
  }

  /// Creates the Firebase Auth account and sends the verification email.
  ///
  /// The remaining fields stay in this widget's state until the flow finishes;
  /// nothing is written to Firestore here. Falls back to the pre-Firebase
  /// behaviour when Firebase is unavailable (e.g. widget tests).
  Future<bool> _register() async {
    if (!AuthService.isAvailable) return true;

    setState(() {
      _busy = true;
      _busyLabel = 'Creating your account…';
    });
    try {
      await AuthService.instance.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      await AuthService.instance.updateDisplayName(_fullName.text.trim());
      await AuthService.instance.sendVerificationEmail();
      return true;
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        await showAuthDialog(
          context,
          title: 'Couldn’t create account',
          message: AuthService.messageFor(error),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        await showAuthDialog(
          context,
          title: 'Something went wrong',
          message: 'Please try again in a moment.',
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  void _finish() => _complete();

  void _skipPhoto() => _complete();

  /// Persists the collected details to Firestore once auth is done, then
  /// leaves for the final loading screen.
  Future<void> _complete() async {
    if (AuthService.isAvailable) {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        setState(() {
          _busy = true;
          _busyLabel = 'Saving your details…';
        });
        try {
          if (_avatarUrl != null) {
            await AuthService.instance.updatePhotoUrl(_avatarUrl!);
          }
          await AuthService.instance.saveUserDetails(
            uid: uid,
            fullName: _fullName.text.trim(),
            username: '_${_username.text.trim().toLowerCase()}',
            email: _email.text.trim(),
            registrationNumber: _regNumber.text.trim(),
            department: _department.text.trim(),
            faculty: _faculty.text.trim(),
            role: _role ?? '',
            level: _level,
            adminId: _role == _adminRole ? _adminId.text.trim() : null,
            photoUrl: _avatarUrl,
          );
        } on FirebaseException catch (error) {
          if (mounted) {
            setState(() {
              _busy = false;
              _busyLabel = null;
            });
            await showAuthDialog(
              context,
              title: 'Couldn’t save your details',
              message: error.message ?? 'Please try again in a moment.',
            );
          }
          return;
        } catch (_) {
          if (mounted) {
            setState(() {
              _busy = false;
              _busyLabel = null;
            });
            await showAuthDialog(
              context,
              title: 'Something went wrong',
              message: 'Please try again in a moment.',
            );
          }
          return;
        }

        // Best-effort: register the device for push and greet the new user.
        await _sendWelcomeNotification(uid);

        if (mounted) {
          setState(() {
            _busy = false;
            _busyLabel = null;
          });
        }
      }
    }
    _continueToLoading();
  }

  /// Stores the FCM token and shows the welcome notification.
  ///
  /// Notifications are best-effort, so failures here never block the account.
  Future<void> _sendWelcomeNotification(String uid) async {
    try {
      final token = await NotificationService.instance.getToken();
      if (token != null) {
        await AuthService.instance.saveFcmToken(uid, token);
      }
      await NotificationService.instance.showWelcome(_fullName.text.trim());
    } catch (_) {
      // Ignore — the account is already created and saved.
    }
  }

  /// Leaves the sign-up flow for the final loading screen.
  void _continueToLoading() {
    Navigator.of(
      context,
    ).pushReplacement(fadeRoute<void>(const GettingReadyScreen()));
  }

  void _pickPhoto() {
    _chooseSource().then((source) async {
      if (source == null) return;

      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _uploading = true;
        _uploadFailed = false;
      });

      try {
        final url = await _media.upload(
          bytes: bytes,
          filename: picked.name,
          contentType: picked.mimeType,
        );
        if (!mounted) return;
        setState(() {
          _avatarUrl = url;
          _uploading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _uploading = false;
          _uploadFailed = true;
        });
      }
    });
  }

  /// Asks where the photo should come from.
  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendEmail() async {
    final email = _email.text.trim();
    if (!AuthService.isAvailable) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Sending…';
    });
    try {
      await AuthService.instance.sendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
      });
      await showAuthDialog(
        context,
        title: 'Email sent',
        message:
            'We sent a fresh verification link to '
            '${email.isEmpty ? 'your email' : email}.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyLabel = null;
      });
      await showAuthDialog(
        context,
        title: 'Couldn’t resend the link',
        message: AuthService.messageFor(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: LoadingOverlay(
        isLoading: _busy,
        message: _busyLabel,
        child: SingleChildScrollView(
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
                          fillColor: SpotifyColors.background,
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
          prefixText: '_',
          textInputAction: TextInputAction.next,
          inputFormatters: [
            _LowerCaseFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
          ],
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return 'Choose a username';
            if (value.length < 3) return 'Use at least 3 characters';
            return null;
          },
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
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return 'Enter your registration number';
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
        // Role follow-up: everyone picks a level (it groups users in the
        // database); admins additionally prove their ID.
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_role != null)
                Padding(
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
              if (_role == _adminRole)
                Padding(
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
            ],
          ),
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
              foregroundColor: SpotifyColors.accent,
              textStyle: AuthScaffold.linkStyle,
            ),
            child: const Text('Resend email'),
          ),
        ),
        const SizedBox(height: 24),
        if (_verificationComplete)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _next,
              child: const Text('Continue'),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLoader(size: 16),
              const SizedBox(width: 12),
              Text(
                'Waiting for you to verify your email…',
                style: AuthScaffold.subtitleStyle,
              ),
            ],
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
              ClipOval(
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: _buildAvatarImage(theme),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: SpotifyColors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _uploading ? null : _pickPhoto,
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
              if (_uploading)
                const Positioned.fill(
                  child: ClipOval(child: ShimmerBox(shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
        if (_uploadFailed) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Couldn’t upload the photo. Tap the camera to try again.',
              textAlign: TextAlign.center,
              style: AuthScaffold.subtitleStyle,
            ),
          ),
        ],
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
              foregroundColor: SpotifyColors.accent,
              textStyle: AuthScaffold.linkStyle,
            ),
            child: const Text('Skip for now'),
          ),
        ),
      ],
    );
  }

  /// The avatar preview: the uploaded image, the picked image, or a
  /// placeholder person glyph.
  Widget _buildAvatarImage(ThemeData theme) {
    final bytes = _avatarBytes;
    final url = _avatarUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : _avatarPlaceholder(theme),
      );
    }
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    return _avatarPlaceholder(theme);
  }

  Widget _avatarPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        size: 52,
        color: theme.colorScheme.onSurfaceVariant,
      ),
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
                    ? SpotifyColors.accent
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

/// Forces typed text to lower case as the user types (usernames are
/// lower-case only).
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
