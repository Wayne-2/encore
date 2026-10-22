import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared four-tier type scale used across the app.
///
/// | tier       | size | weight | colour                    |
/// |------------|------|--------|---------------------------|
/// | heading    | 18   | w700   | onSurface                 |
/// | title      | 15   | w700   | onSurface (hierarchy)     |
/// | subtitle   | 15   | w400   | onSurface (hierarchy)     |
/// | functional | 12   | w400   | onSurfaceVariant (lifted) |
///
/// The navigation bar and workspace app bar keep their own compact sizes.
abstract final class AppType {
  /// Opacity step between adjacent hierarchy tiers.
  static const double opacityStep = 0.2;

  /// Opacity for [fontSize], encoding the hierarchy in [opacityStep] steps.
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

  /// Section and page headings — 18sp bold primary text.
  static TextStyle heading(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: s.onSurface,
    ),
  );

  /// The muted `#` glyph that prefixes a section heading.
  static TextStyle glyph(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1,
    color: s.onSurfaceVariant.withValues(alpha: 0.7),
  );

  /// Names and primary item titles — 15sp bold text.
  static TextStyle title(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: s.onSurface,
    ),
  );

  /// Supporting copy such as previews and descriptions — 15sp regular text.
  static TextStyle subtitle(ColorScheme s) => withHierarchy(
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: s.onSurface,
    ),
  );

  /// Timestamps, labels and compact utility copy — 12sp regular text.
  static TextStyle functional(ColorScheme s) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: s.onSurfaceVariant.withValues(alpha: 0.7),
  );

  // Backwards-compatible semantic aliases mapped onto the four tiers.
  static TextStyle sectionTitle(ColorScheme s) => heading(s);
  static TextStyle name(ColorScheme s) => title(s);
  static TextStyle cardTitle(ColorScheme s) => title(s);
  static TextStyle body(ColorScheme s) => subtitle(s);
  static TextStyle timestamp(ColorScheme s) => functional(s);
  static TextStyle meta(ColorScheme s) => functional(s);

  /// Long-form reading copy — 15sp regular with generous leading.
  static TextStyle reading(ColorScheme s) =>
      subtitle(s).copyWith(height: 1.75, color: s.onSurface);

  /// Coloured priority/tag label.
  static TextStyle tag(Color color) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
  );
}
