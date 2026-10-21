import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared text hierarchy used across the non-auth pages, following Spotify's
/// type scale. The announcement feed opts into `SlackType` instead.
///
/// Prominence is expressed through size, weight and colour, top → bottom:
///
/// | tier       | size | weight | colour      |
/// |------------|------|--------|-------------|
/// | section    | 22   | w700   | primary     |
/// | name       | 16   | w700   | primary     |
/// | card title | 15   | w700   | primary     |
/// | body       | 15   | w400   | subdued     |
/// | subtitle   | 13   | w400   | subdued     |
/// | meta / tag | 11   | w400/600 | faint/subdued |
abstract final class AppType {
  /// Opacity step between adjacent hierarchy tiers.
  static const double opacityStep = 0.2;

  /// Opacity for [fontSize], encoding the hierarchy in [opacityStep] steps: the
  /// largest tier (18sp+ section headings) stays fully opaque and each smaller
  /// tier drops by [opacityStep], bottoming out at 0.2 for the caption tier.
  static double hierarchyOpacity(double fontSize) {
    if (fontSize >= 18) return 1.0;
    if (fontSize >= 16) return 1.0 - opacityStep;
    if (fontSize >= 15) return 1.0 - opacityStep * 2;
    if (fontSize >= 13) return 1.0 - opacityStep * 3;
    return 1.0 - opacityStep * 4;
  }

  /// [style] with its colour opacity set to [hierarchyOpacity] for its size.
  static TextStyle withHierarchy(TextStyle style) {
    final color = style.color;
    if (color == null) return style;
    return style.copyWith(
      color: color.withValues(alpha: hierarchyOpacity(style.fontSize ?? 0)),
    );
  }

  /// Section titles — Spotify's 22sp bold headings.
  static TextStyle sectionTitle(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: s.onSurface,
    ),
  );

  /// The muted `#` glyph that prefixes a section title.
  static TextStyle glyph(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1,
    color: s.onSurfaceVariant.withValues(alpha: 0.7),
  );

  /// Names and primary list titles — Spotify's 16sp bold item titles.
  static TextStyle name(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: s.onSurface,
    ),
  );

  /// Message copy — 15sp regular subdued text.
  static TextStyle body(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: s.onSurfaceVariant,
    ),
  );

  /// Long-form reading copy — 16sp regular with generous leading so library
  /// documents stay comfortable over several screens.
  static TextStyle reading(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 16,
    height: 1.75,
    fontWeight: FontWeight.w400,
    color: s.onSurface,
  );

  /// Card and list-item titles — 15sp bold primary text, one step below
  /// [name] so headings stay dominant.
  static TextStyle cardTitle(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: s.onSurface,
    ),
  );

  /// Supporting copy such as card subtitles and dates — 13sp subdued.
  static TextStyle subtitle(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: s.onSurfaceVariant,
    ),
  );

  /// Timestamps — the faintest tier.
  static TextStyle meta(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: s.onSurfaceVariant,
    ),
  );

  /// Coloured priority/tag label.
  static TextStyle tag(Color color) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: color,
  );
}
