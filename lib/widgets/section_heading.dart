import 'package:flutter/material.dart';

import '../theme/app_type.dart';

/// Slack-style section heading: a muted `#` glyph followed by the section name.
///
/// Shared by the home sections (Updates, Finance, …) so their titles stay
/// visually identical.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.style, this.glyphStyle});

  final String title;

  /// Overrides the default [AppType.sectionTitle] style — lets a section
  /// opt into a larger heading (e.g. the Trending row's Spotify-style title).
  final TextStyle? style;

  /// Overrides the default [AppType.glyph] style for the leading `#`.
  final TextStyle? glyphStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('#', style: glyphStyle ?? AppType.glyph(scheme)),
        const SizedBox(width: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style ?? AppType.sectionTitle(scheme),
        ),
      ],
    );
  }
}
