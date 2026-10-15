import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Minimal branded top bar for the auth screens: the Encore wordmark.
class AuthTopBar extends StatelessWidget {
  const AuthTopBar({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Image.asset('assets/Encore.png', width: 24, height: 24),
        const SizedBox(width: 8),
        Text(
          title ?? 'Encore',
          style: TextStyle(
            fontFamily: AppTheme.brandFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
