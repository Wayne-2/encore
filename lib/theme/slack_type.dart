import 'package:flutter/material.dart';

import 'app_type.dart';

/// Slack-flavoured aliases backed by the shared four-tier scale in [AppType].
///
/// The announcement feed and conversation tiles keep their Slack layout, but
/// now share the same heading, title, subtitle and functional sizes as the
/// rest of the app.
abstract final class SlackType {
  static TextStyle sectionTitle(ColorScheme s) => AppType.heading(s);
  static TextStyle glyph(ColorScheme s) => AppType.glyph(s);
  static TextStyle sender(ColorScheme s) => AppType.title(s);
  static TextStyle body(ColorScheme s) => AppType.subtitle(s);
  static TextStyle timestamp(ColorScheme s) => AppType.functional(s);
}
