import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';
import 'user_avatar.dart';

/// Slack-style workspace bar shared by the sections of [HomeShell].
///
/// Shows an anchor glyph, a section [heading], an optional [title] underneath,
/// and a trailing widget (the signed-in user's avatar by default).
class WorkspaceAppBar extends StatelessWidget {
  const WorkspaceAppBar({
    super.key,
    required this.heading,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.headingSize,
    this.headingWeight,
  });

  final String heading;
  final String? title;

  /// Optional custom widget rendered beneath [heading] instead of [title].
  final Widget? subtitle;

  /// Optional replacement for the anchor glyph, such as a back button.
  final Widget? leading;

  /// Widget shown at the far right. Defaults to the signed-in user's avatar.
  final Widget? trailing;

  /// Custom font size for the heading. Defaults to 16.
  final double? headingSize;

  /// Custom font weight for the heading. Defaults to [FontWeight.w700].
  final FontWeight? headingWeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      height: 64 + topInset,
      color: SpotifyColors.background,
      padding: EdgeInsets.only(top: topInset, left: 16, right: 16),
      child: Row(
        children: [
          leading ??
              SvgPicture.asset(
                'assets/icons/anchor.svg',
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  scheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: headingSize ?? 16,
                    fontWeight: headingWeight ?? FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ] else if (title != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ?? const CurrentUserAvatar(size: 38),
        ],
      ),
    );
  }
}
