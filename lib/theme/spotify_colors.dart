import 'package:flutter/material.dart';

/// Spotify dark-mode design tokens.
///
/// The whole app runs Spotify's dark appearance: a near-black base
/// (`#121212`), lightly elevated surfaces (`#181818`), pure-white primary
/// text and `#B3B3B3` subdued text, separated by translucent white hairlines.
/// The brand accent stays the app's signature green rather than Spotify's.
abstract final class SpotifyColors {
  /// App background — Spotify's base black.
  static const Color background = Color(0xFF121212);

  /// Elevated surface — cards, sheets, menus and the bottom bar.
  static const Color surface = Color(0xFF181818);

  /// Hover/pressed surface — one step above [surface].
  static const Color surfaceHover = Color(0xFF282828);

  /// Primary text — pure white.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Subdued text — Spotify's secondary grey.
  static const Color textSubdued = Color(0xFFB3B3B3);

  /// Hairline border/divider — 10% white.
  static const Color border = Color(0x1AFFFFFF);

  /// Stronger border — 20% white.
  static const Color borderStrong = Color(0x33FFFFFF);

  /// Brand accent — the app's signature green, kept over Spotify green.
  static const Color accent = Color(0xFF25A10C);

  /// Outgoing chat bubble — a deep, muted green so long conversations do not
  /// glare while still reading as the app's brand colour.
  static const Color chatOutgoing = Color(0xB325A10C);

  /// Destructive/status red.
  static const Color danger = Color(0xFFF04438);

  // ---- Announcement priority tags ----
  /// Amber — "Highly prior" announcements.
  static const Color tagUrgent = Color(0xFFE8A33D);

  /// Blue — general announcements.
  static const Color tagInfo = Color(0xFF6FA8DC);

  /// Grey — low priority announcements.
  static const Color tagMuted = Color(0xFF9AA0A6);
}
