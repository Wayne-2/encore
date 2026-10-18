import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_type.dart';

/// Slack mobile typography, used by the announcement feed so that section
/// keeps Slack's exact message-list sizing while the rest of the app follows
/// the Spotify hierarchy in `AppType`. Most colours carry the shared size-based
/// opacity ramp from [AppType.hierarchyOpacity]; timestamps are lifted so they
/// remain legible.
abstract final class SlackType {
  /// Section heading — Slack's 18sp bold list header.
  static TextStyle sectionTitle(ColorScheme s) => AppType.withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: s.onSurface,
    ),
  );

  /// The `#` glyph that prefixes the announcement heading.
  static TextStyle glyph(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1,
    color: s.onSurfaceVariant.withValues(alpha: 0.7),
  );

  /// Message sender — Slack's 15sp bold name.
  static TextStyle sender(ColorScheme s) => AppType.withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: s.onSurface,
    ),
  );

  /// Message body — Slack's 15sp regular copy at 1.4 line-height.
  static TextStyle body(ColorScheme s) => AppType.withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: s.onSurface,
    ),
  );

  /// Message timestamp — Slack's 12sp caption, lifted above the size-based
  /// opacity ramp so it stays clearly legible.
  static TextStyle timestamp(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: s.onSurfaceVariant.withValues(alpha: 0.7),
  );
}
