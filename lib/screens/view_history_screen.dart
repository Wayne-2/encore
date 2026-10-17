import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/slack_colors.dart';

/// Placeholder history page for finance transactions.
class ViewHistoryScreen extends StatelessWidget {
  const ViewHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: SlackColors.darkBackground,
      appBar: AppBar(
        backgroundColor: SlackColors.darkHeader,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'View History',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'No history yet',
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
