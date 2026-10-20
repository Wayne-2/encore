import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';
import '../widgets/edit_profile_sheet.dart';

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
  String? _photoUrl;

  String _role = 'Student';
  String _registrationNumber = '20241426282';
  String _department = 'Computer Science';
  String _level = '300 Level';
  String _faculty = 'SICT';

  @override
  void initState() {
    super.initState();
    _loadCached();
    _load();
  }

  /// Renders the last profile saved on this device before Firestore responds.
  Future<void> _loadCached() async {
    if (!AuthService.isAvailable) return;
    final data = await AuthService.instance.cachedProfile();
    if (!mounted || data == null) return;
    _applyProfile(data);
  }

  Future<void> _load() async {
    if (!AuthService.isAvailable) return;
    try {
      final data = await AuthService.instance.currentUserProfile();
      if (!mounted || data == null) return;
      _applyProfile(data);
    } catch (_) {
      // Keep the cached/design fallback when the profile can't be read.
    }
  }

  void _applyProfile(Map<String, dynamic> data) {
    final fullName = data['fullName'] as String?;
    final username = data['username'] as String?;
    final email = data['email'] as String?;
    final bio = data['bio'] as String?;
    final photoUrl = data['photoUrl'] as String?;
    final role = data['role'] as String?;
    final registrationNumber = data['registrationNumber'] as String?;
    final department = data['department'] as String?;
    final level = data['level'] as String?;
    final faculty = data['faculty'] as String?;

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
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        _photoUrl = photoUrl;
      }
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
    final saved = await showEditProfileSheet(
      context,
      username: _username,
      bio: _hasStoredBio ? _bio : '',
      photoUrl: _photoUrl,
    );
    if (saved == true) await _load();
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
            : Image.network(
                _photoUrl!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => Image.asset(
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
                        Text('See profile', style: AppType.meta(scheme)),
                        const SizedBox(height: 10),
                        _CircleIcon(
                          icon: Icons.share_outlined,
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
                  icon: Icons.insights,
                  title: 'Student Performance',
                  subtitle: 'Track and manage your performance as a student',
                ),
                const SizedBox(height: 12),
                const _ProfileActionTile(
                  icon: Icons.checklist_rounded,
                  title: 'Personal todo',
                  subtitle:
                      'Add todos and schedule personal activities with timer',
                ),
                const SizedBox(height: 12),
                const _ProfileActionTile(
                  icon: Icons.support_agent,
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
                    style: AppType.meta(scheme),
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
                    Text(subtitle, style: AppType.meta(scheme)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios,
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
