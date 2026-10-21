import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/auth_service.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/cached_profile_image.dart';
import '../widgets/edit_profile_sheet.dart';

/// Small supporting text on the profile page. Kept slightly brighter and
/// heavier than [AppType.meta] so it stays legible over the hero image.
TextStyle _profileMetaStyle(ColorScheme scheme) {
  return AppType.meta(scheme).copyWith(
    color: scheme.onSurface.withValues(alpha: 0.65),
    fontWeight: FontWeight.w500,
  );
}

/// The Profile section — the fourth tab of [HomeShell].
///
/// A full-bleed hero profile modelled on the supplied `profiledesign.jpeg`: a
/// portrait photo fading into the app background, the name, handle, bio and a
/// bordered details banner.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _bioPlaceholder = 'Edit your profile to add your bio';

  String _fullName = 'Odeh\nSolomon';
  String _username = '_wayne';
  String _email = 'sodeh138@gmail.com';
  String _bio = _bioPlaceholder;
  bool _hasStoredBio = false;
  bool _loading = true;
  bool _loadFailed = false;
  String? _photoUrl;
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;

  String _role = 'Student';
  String _registrationNumber = '20241426282';
  String _department = 'Computer Science';
  String _level = '300 Level';
  String _faculty = 'SICT';

  @override
  void initState() {
    super.initState();
    _listenToProfile();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  /// Hive answers first, then Firestore pushes any profile/photo updates.
  void _listenToProfile() {
    if (!AuthService.isAvailable) {
      _loading = false;
      return;
    }

    var hasProfile = false;
    _profileSubscription = AuthService.instance
        .currentUserProfileStream()
        .listen(
          (data) {
            if (!mounted) return;
            if (data != null) {
              hasProfile = true;
              _applyProfile(data);
            }
            setState(() {
              _loading = false;
              if (hasProfile) _loadFailed = false;
            });
          },
          onError: (Object error) {
            debugPrint('Profile stream failed: $error');
            if (!mounted) return;
            setState(() {
              _loading = false;
              _loadFailed = !hasProfile;
            });
          },
        );
  }

  /// Manual retry for the error banner; normal updates arrive via the stream.
  Future<void> _load() async {
    if (!AuthService.isAvailable) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!_loading) setState(() => _loading = true);

    try {
      final data = await AuthService.instance.currentUserProfile(
        fallbackToCache: false,
      );
      if (!mounted) return;
      if (data == null) throw StateError('Profile document was not found.');
      _applyProfile(data);
      setState(() {
        _loading = false;
        _loadFailed = false;
      });
    } catch (error) {
      debugPrint('Profile load failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _applyProfile(Map<String, dynamic> data) {
    String? read(String key) {
      final value = data[key];
      return value is String ? value : null;
    }

    final fullName = read('fullName');
    final username = read('username');
    final email = read('email');
    final bio = read('bio');
    final photoUrl = read('photoUrl');
    final role = read('role');
    final registrationNumber = read('registrationNumber');
    final department = read('department');
    final level = read('level');
    final faculty = read('faculty');

    setState(() {
      if (fullName != null && fullName.trim().isNotEmpty) {
        _fullName = fullName;
      }
      if (username != null && username.trim().isNotEmpty) {
        _username = username;
      }
      if (email != null && email.trim().isNotEmpty) {
        _email = email;
      }
      if (bio != null) {
        _bio = bio;
        _hasStoredBio = true;
      }
      _photoUrl = (photoUrl != null && photoUrl.trim().isNotEmpty)
          ? photoUrl
          : null;
      if (role != null && role.trim().isNotEmpty) {
        final value = role.trim();
        _role = value[0].toUpperCase() + value.substring(1);
      }
      if (registrationNumber != null && registrationNumber.trim().isNotEmpty) {
        _registrationNumber = registrationNumber.trim();
      }
      if (department != null && department.trim().isNotEmpty) {
        _department = department.trim();
      }
      if (level != null && level.trim().isNotEmpty) {
        _level = level.trim();
      }
      if (faculty != null && faculty.trim().isNotEmpty) {
        _faculty = faculty.trim();
      }
    });
  }

  Future<void> _editProfile() async {
    try {
      await showEditProfileSheet(
        context,
        username: _username,
        bio: _hasStoredBio ? _bio : '',
        photoUrl: _photoUrl,
      );
    } catch (error) {
      debugPrint('Profile editor failed to open: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Couldn’t open the profile editor. Try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    final hasBio = _bio.trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        _photoUrl == null
            ? Image.asset(
                'assets/Encore.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              )
            : CachedProfileImage(
                url: _photoUrl!,
                fit: BoxFit.cover,
                fallback: Image.asset(
                  'assets/Encore.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SpotifyColors.background.withValues(alpha: 0.45),
                Colors.transparent,
                SpotifyColors.background.withValues(alpha: 0.7),
                SpotifyColors.background,
              ],
              stops: const [0.0, 0.25, 0.62, 0.92],
            ),
          ),
        ),
        // Top controls
        Positioned(
          top: topInset + 8,
          left: 16,
          right: 16,
          child: Row(
            children: [
              const Spacer(),
              _EditProfileButton(onTap: _editProfile),
            ],
          ),
        ),
        if (_loadFailed)
          Positioned(
            top: topInset + 56,
            left: 16,
            right: 16,
            child: _ProfileLoadError(loading: _loading, onRetry: _load),
          ),
        // Hero details
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sectionTitle(
                          scheme,
                        ).copyWith(fontSize: 30, height: 1.1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('See profile', style: _profileMetaStyle(scheme)),
                        const SizedBox(height: 10),
                        _CircleIcon(
                          icon: LucideIcons.share2,
                          color: scheme.onSurface,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Text(_username, style: AppType.tag(scheme.primary)),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.subtitle(scheme).copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hasBio ? _bio : _bioPlaceholder,
                  style: AppType.body(scheme).copyWith(
                    color: hasBio ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                _DetailsBanner(
                  role: _role,
                  registrationNumber: _registrationNumber,
                  department: _department,
                  level: _level,
                  faculty: _faculty,
                ),
                const SizedBox(height: 12),
                const _ProfileActionTile(
                  icon: LucideIcons.trendingUp,
                  title: 'Student Performance',
                  subtitle: 'Track and manage your performance as a student',
                ),
                const SizedBox(height: 12),
                const _ProfileActionTile(
                  icon: LucideIcons.listChecks,
                  title: 'Personal todo',
                  subtitle:
                      'Add todos and schedule personal activities with timer',
                ),
                const SizedBox(height: 12),
                const _ProfileActionTile(
                  icon: LucideIcons.headphones,
                  title: 'Student Assistant',
                  subtitle: 'Request Student assistance from Agents',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact banner shown when the profile could not be refreshed. The cached
/// profile stays visible behind it so the page is never blank.
class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.loading, required this.onRetry});

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      key: const ValueKey('profile-load-error'),
      color: SpotifyColors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: SpotifyColors.danger.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.cloudOff,
              size: 18,
              color: SpotifyColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Couldn’t refresh your profile.',
                style: AppType.subtitle(scheme).copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(
                key: const ValueKey('profile-retry'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// The translucent "Edit Profile" pill shown over the hero.
class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Edit Profile',
            style: AppType.subtitle(
              scheme,
            ).copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// A circular translucent icon button used in the hero.
class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpotifyColors.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

/// A bordered banner of profile details plus a privacy toggle.
class _DetailsBanner extends StatefulWidget {
  const _DetailsBanner({
    required this.role,
    required this.registrationNumber,
    required this.department,
    required this.level,
    required this.faculty,
  });

  final String role;
  final String registrationNumber;
  final String department;
  final String level;
  final String faculty;

  @override
  State<_DetailsBanner> createState() => _DetailsBannerState();
}

class _DetailsBannerState extends State<_DetailsBanner> {
  bool _isPrivate = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DotRow(
            items: [widget.role, widget.registrationNumber],
            emphasize: true,
          ),
          const SizedBox(height: 10),
          _DotRow(items: [widget.department, widget.level, widget.faculty]),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Privacy Mode',
                    style: AppType.subtitle(scheme).copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isPrivate ? 'Profile is private' : 'Profile is public',
                    style: _profileMetaStyle(scheme),
                  ),
                ],
              ),
              const Spacer(),
              Switch(
                key: const ValueKey('profile-privacy-toggle'),
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A row of labels separated by small circular dots.
class _DotRow extends StatelessWidget {
  const _DotRow({required this.items, this.emphasize = false});

  final List<String> items;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppType.subtitle(scheme).copyWith(
      color: emphasize ? scheme.onSurface : scheme.onSurfaceVariant,
      fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
    );

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(items[i], style: style),
        ],
      ],
    );
  }
}

/// A tappable, banner-styled row with a leading icon, title/subtitle and a
/// trailing chevron.
class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _GlassPanel(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          child: Row(
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppType.subtitle(scheme).copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _profileMetaStyle(scheme)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A frosted, translucent panel shared by the profile details banner and the
/// action tiles, so content stays legible over the hero image.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: SpotifyColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
