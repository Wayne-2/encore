import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'chat_avatar.dart';

const List<Color> _avatarPalette = [
  Color(0xFF1F7A4D),
  Color(0xFF1F5F8B),
  Color(0xFF7A4D9E),
  Color(0xFF9E4D5B),
  Color(0xFF8B6A1F),
  Color(0xFF3D6B8B),
];

String initialsForName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .map((part) => part.replaceFirst(RegExp(r'^_+'), ''))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

Color avatarColorFor(String seed) {
  final value = seed.trim().isEmpty ? 'Encore user' : seed.trim();
  final sum = value.codeUnits.fold<int>(0, (total, unit) => total + unit);
  return _avatarPalette[sum % _avatarPalette.length];
}

/// A consistent profile avatar: photo first, initials as the fallback.
///
/// Pass [userId] for content authored by another account (comments, posts,
/// messages) so the avatar resolves that account's current profile photo
/// rather than relying on a URL snapshot stored with the content.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.userId,
    this.photoUrl,
    this.initials,
    this.size = 36,
    this.showOnlineDot = false,
  });

  final String name;
  final String? userId;
  final String? photoUrl;
  final String? initials;
  final double size;
  final bool showOnlineDot;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Stream<Map<String, dynamic>?>? _profile;

  @override
  void initState() {
    super.initState();
    _bindProfile();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _bindProfile();
  }

  void _bindProfile() {
    final uid = widget.userId?.trim();
    _profile = AuthService.isAvailable && uid != null && uid.isNotEmpty
        ? AuthService.instance.userProfileStreamFor(uid)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _profile;
    if (stream == null) {
      return _avatar(widget.name, widget.photoUrl, widget.initials);
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final fullName = (data?['fullName'] as String?)?.trim();
        final username = (data?['username'] as String?)?.trim();
        final resolvedName = fullName != null && fullName.isNotEmpty
            ? fullName
            : username != null && username.isNotEmpty
            ? username
            : widget.name;
        final storedPhoto = (data?['photoUrl'] as String?)?.trim();
        final resolvedPhoto = storedPhoto != null && storedPhoto.isNotEmpty
            ? storedPhoto
            : widget.photoUrl;

        return _avatar(resolvedName, resolvedPhoto, widget.initials);
      },
    );
  }

  Widget _avatar(String name, String? photoUrl, String? initials) {
    return ChatAvatar(
      avatarUrl: photoUrl,
      avatarInitials: initials ?? initialsForName(name),
      avatarColor: avatarColorFor(name),
      size: widget.size,
      borderRadius: BorderRadius.circular(4),
      showOnlineDot: widget.showOnlineDot,
    );
  }
}

/// The signed-in user's avatar, kept live across every page header.
class CurrentUserAvatar extends StatefulWidget {
  const CurrentUserAvatar({super.key, this.size = 38});

  final double size;

  @override
  State<CurrentUserAvatar> createState() => _CurrentUserAvatarState();
}

class _CurrentUserAvatarState extends State<CurrentUserAvatar> {
  Stream<Map<String, dynamic>?>? _profile;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAvailable) {
      _profile = AuthService.instance.currentUserProfileStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _profile;
    if (stream == null) {
      return UserAvatar(name: _fallbackName, size: widget.size);
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final fullName = (data?['fullName'] as String?)?.trim();
        final username = (data?['username'] as String?)?.trim();
        final photoUrl = (data?['photoUrl'] as String?)?.trim();
        final name = fullName != null && fullName.isNotEmpty
            ? fullName
            : username != null && username.isNotEmpty
            ? username
            : _fallbackName;

        return UserAvatar(name: name, photoUrl: photoUrl, size: widget.size);
      },
    );
  }

  String get _fallbackName {
    if (!AuthService.isAvailable) return 'You';
    final displayName = AuthService.instance.currentUser?.displayName?.trim();
    return displayName != null && displayName.isNotEmpty ? displayName : 'You';
  }
}
