import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import 'cached_profile_image.dart';

/// A squircle avatar widget matching the screenshot's rounded-corner style.
///
/// Supports bundled image assets, custom branding (e.g. LFX Academia), or
/// initials, with an optional online status badge.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    this.avatarAsset,
    this.avatarUrl,
    this.avatarColor,
    this.avatarInitials,
    this.size = 52,
    this.borderRadius,
    this.showOnlineDot = false,
  });

  final String? avatarAsset;
  final String? avatarUrl;
  final Color? avatarColor;
  final String? avatarInitials;
  final double size;
  final BorderRadius? borderRadius;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(4);
    final dotSize = size * 0.22;
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();

    Widget content;

    if (avatarInitials == 'LFX') {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF3B0764),
          borderRadius: radius,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LFX',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: size * 0.30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ACADEMIA',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      final fallback = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: avatarColor ?? SpotifyColors.background,
          borderRadius: radius,
        ),
        child: Center(
          child: Text(
            avatarInitials ?? '?',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
      content = ClipRRect(
        borderRadius: radius,
        child: CachedProfileImage(
          url: avatarUrl!,
          width: size,
          height: size,
          fallback: fallback,
        ),
      );
    } else if (avatarAsset != null) {
      if (avatarAsset!.endsWith('Encore.png')) {
        content = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: SpotifyColors.surface,
            borderRadius: radius,
          ),
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset(
            avatarAsset!,
            fit: BoxFit.contain,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            filterQuality: FilterQuality.medium,
          ),
        );
      } else {
        content = ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            avatarAsset!,
            width: size,
            height: size,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        );
      }
    } else {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: avatarColor ?? SpotifyColors.background,
          borderRadius: radius,
        ),
        child: Center(
          child: Text(
            avatarInitials ?? '?',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (!showOnlineDot) {
      return content;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: SpotifyColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: SpotifyColors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
