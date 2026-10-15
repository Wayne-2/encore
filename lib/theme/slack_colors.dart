import 'package:flutter/material.dart';

/// Slack mobile design tokens.
///
/// Colors follow Slack's aubergine-branded palette used across its mobile
/// apps (iOS / Android), covering both the light and dark appearances.
abstract final class SlackColors {
  // ---- Brand / chrome ----
  /// Sidebar and app-bar aubergine background.
  static const Color aubergine = Color(0xFF3F0E40);

  /// Darker aubergine used for hovers and pressed states in the sidebar.
  static const Color aubergineDark = Color(0xFF350D36);

  /// Deepest aubergine used for the workspace switcher / sheets.
  static const Color aubergineDarkest = Color(0xFF24092B);

  /// Slack brand purple (badges, accents).
  static const Color purple = Color(0xFF611F69);

  /// Active/action green used for primary CTAs (matches the welcome button).
  static const Color accentGreen = Color(0xFF25A10C);

  // ---- Announcement priority tags ----
  /// Amber — "Highly prior" announcements.
  static const Color tagUrgent = Color(0xFFE8A33D);

  /// Blue — general announcements.
  static const Color tagInfo = Color(0xFF6FA8DC);

  /// Grey — low priority announcements.
  static const Color tagMuted = Color(0xFF9AA0A6);

  // ---- Light appearance ----
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF8F8F8);
  static const Color lightSurfaceSecondary = Color(0xFFF4EDE4);
  static const Color lightBorder = Color(0xFFE8E8E8);
  static const Color lightBorderStrong = Color(0xFFDDDDDD);
  static const Color lightTextPrimary = Color(0xFF1D1C1D);
  static const Color lightTextSecondary = Color(0xFF616061);
  static const Color lightTextOnAubergine = Color(0xFFFFFFFF);
  static const Color lightTextSidebarInactive = Color(0xFFBCABBC);
  static const Color lightHover = Color(0xFFF8F8F8);
  static const Color lightSelected = Color(0xFF1164A3);

  // ---- Dark appearance ----
  static const Color darkBackground = Color(0xFF1A1D21);
  static const Color darkSurface = Color(0xFF222529);
  static const Color darkSurfaceSecondary = Color(0xFF27242C);

  /// Header / app-bar surface for the signed-in sections (e.g. Updates).
  static const Color darkHeader = Color(0xFF22252A);
  static const Color darkBorder = Color(0xFF393B40);
  static const Color darkBorderStrong = Color(0xFF454548);
  static const Color darkTextPrimary = Color(0xFFD1D2D3);
  static const Color darkTextSecondary = Color(0xFFABABAD);
  static const Color darkHover = Color(0xFF2C2D31);
  static const Color darkSelected = Color(0xFF1D9BD1);

  // ---- Accents & status ----
  /// Slack blue – links, primary buttons, selection.
  static const Color blue = Color(0xFF1264A3);

  /// Lighter blue used for hover/pressed on blue elements.
  static const Color blueLight = Color(0xFF1D9BD1);

  /// Green – online presence, success.
  static const Color green = Color(0xFF2BAC76);

  /// Darker green used for primary button fills.
  static const Color greenDark = Color(0xFF007A5A);

  /// Yellow / gold – mentions, highlights, away presence.
  static const Color yellow = Color(0xFFECB22E);

  /// Red / crimson – destructive actions, errors, notifications.
  static const Color red = Color(0xFFE01E5A);

  /// Orange – warnings.
  static const Color orange = Color(0xFFE8912D);
}
