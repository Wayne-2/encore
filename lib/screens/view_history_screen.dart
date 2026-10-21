import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// Placeholder history page for finance transactions.
class ViewHistoryScreen extends StatelessWidget {
  const ViewHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('View History', style: AppType.name(scheme)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt, size: 34, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No history yet',
              key: const ValueKey('no-history-message'),
              style: AppType.timestamp(scheme),
            ),
          ],
        ),
      ),
    );
  }
}
