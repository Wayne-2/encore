import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/spotify_colors.dart';

/// Dark scaffold used across the auth flow, matching the splash screen's
/// `#1A1D21` background. Provides shared typography + a branded top bar.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.body});

  final Widget body;

  static TextStyle get titleStyle => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: Colors.white,
  );

  static TextStyle get subtitleStyle => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Colors.white70,
  );

  static TextStyle get labelStyle => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );

  static TextStyle get linkStyle => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: SpotifyColors.accent,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: SafeArea(child: body),
    );
  }
}
