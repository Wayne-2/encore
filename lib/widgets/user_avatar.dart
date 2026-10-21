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
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.initials,
    this.size = 36,
    this.showOnlineDot = false,
  });

  final String name;
  final String? photoUrl;
  final String? initials;
  final double size;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    return ChatAvatar(
      avatarUrl: photoUrl,
      avatarInitials: initials ?? initialsForName(name),
      avatarColor: avatarColorFor(name),
      size: size,
      borderRadius: BorderRadius.circular(4),
      showOnlineDot: showOnlineDot,
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
