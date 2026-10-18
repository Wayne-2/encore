import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spotify_colors.dart';

/// Placeholder destination for the Updates "Show more" action.
class TrendingMoreScreen extends StatelessWidget {
  const TrendingMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Trending',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Trending — coming soon',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
