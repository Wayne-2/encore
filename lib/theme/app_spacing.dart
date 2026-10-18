/// Shared 4pt spacing scale, matching Spotify's layout rhythm.
///
/// Every non-auth page uses these values so section gaps, page padding and
/// carousel spacing stay consistent app-wide.
abstract final class AppSpacing {
  /// Horizontal page padding.
  static const double page = 16;

  /// Vertical gap between page sections.
  static const double section = 24;

  /// Gap between a section heading and its content.
  static const double heading = 12;

  /// Gap between cards in a horizontal carousel.
  static const double card = 12;

  /// Gap between a card's artwork and its title.
  static const double artText = 8;

  /// Gap between a card's title and subtitle.
  static const double text = 2;
}
