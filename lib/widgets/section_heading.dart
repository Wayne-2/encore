import 'package:flutter/material.dart';

import '../theme/app_type.dart';

/// Slack-style section heading: a muted `#` glyph followed by the section name.
///
/// Shared by the home sections (Updates, Finance, …) so their titles stay
/// visually identical.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('#', style: AppType.glyph(scheme)),
        const SizedBox(width: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.sectionTitle(scheme),
        ),
      ],
    );
  }
}
