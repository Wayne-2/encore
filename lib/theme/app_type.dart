import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared text hierarchy used across the home sections (Updates, Finance, …).
///
/// Prominence is expressed through size, weight and opacity rather than colour
/// alone, top → bottom:
///
/// | tier       | size | weight | opacity |
/// |------------|------|--------|---------|
/// | section    | 16   | w600   | 100%    |
/// | name       | 15   | w700   | 100%    |
/// | card title | 14   | w600   | muted   |
/// | body       | 14   | w400   | 100%    |
/// | subtitle   | 12   | w400   | 80%     |
/// | meta / tag | 11   | w600   | 60–100% |
abstract final class AppType {
  /// Section titles — the top of the hierarchy.
  static TextStyle sectionTitle(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: s.onSurface,
  );

  /// The muted `#` glyph that prefixes a section title.
  static TextStyle glyph(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1,
    color: s.onSurfaceVariant.withValues(alpha: 0.7),
  );

  /// Names and card titles — primary emphasis.
  static TextStyle name(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: s.onSurface,
  );

  /// Message copy — secondary emphasis.
  static TextStyle body(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: s.onSurfaceVariant,
  );

  /// Card and list-item titles — one step below [sectionTitle] in prominence:
  /// smaller and muted, so headings stay dominant.
  static TextStyle cardTitle(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: s.onSurfaceVariant,
  );

  /// Supporting copy such as card subtitles and dates — tertiary emphasis.
  static TextStyle subtitle(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: s.onSurfaceVariant.withValues(alpha: 0.8),
  );

  /// Timestamps — the faintest tier.
  static TextStyle meta(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: s.onSurfaceVariant.withValues(alpha: 0.6),
  );

  /// Coloured priority/tag label.
  static TextStyle tag(Color color) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: color,
  );
}
