import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'spotify_colors.dart';

/// Application themes modeled on Spotify's dark appearance.
///
/// Use [AppTheme.dark] with `MaterialApp.theme`; every page — including the
/// light `theme` slot — renders the Spotify dark palette so the app never
/// leaves dark mode. The accent stays the app's signature green with black
/// on-accent text, matching Spotify's black-on-green buttons.
abstract final class AppTheme {
  /// Brand typeface, bundled from `assets/fonts`.
  static const String fontFamily = 'Montserrat';

  /// Wordmark style for the launch/splash screen.
  static TextStyle get splashWordmarkStyle => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: Colors.white,
  );

  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle style(double size, FontWeight weight, {double? height}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: primary,
        );

    return TextTheme(
      displayLarge: style(24, FontWeight.w400, height: 30 / 24),
      displayMedium: style(22, FontWeight.w400, height: 28 / 22),
      displaySmall: style(20, FontWeight.w700, height: 26 / 20),
      headlineLarge: style(20, FontWeight.w700, height: 26 / 20),
      headlineMedium: style(18, FontWeight.w700, height: 24 / 18),
      headlineSmall: style(17, FontWeight.w500, height: 22 / 17),
      titleLarge: style(16, FontWeight.w700, height: 21 / 16),
      titleMedium: style(
        15,
        FontWeight.w600,
        height: 20 / 15,
      ).copyWith(color: secondary),
      titleSmall: style(
        14,
        FontWeight.w400,
        height: 19 / 14,
      ).copyWith(color: secondary),
      bodyLarge: style(15, FontWeight.w400, height: 20 / 15),
      bodyMedium: style(15, FontWeight.w400, height: 20 / 15),
      bodySmall: style(
        13,
        FontWeight.w400,
        height: 18 / 13,
      ).copyWith(color: secondary),
      labelLarge: style(15, FontWeight.w700, height: 20 / 15),
      labelMedium: style(
        13,
        FontWeight.w500,
        height: 16 / 13,
      ).copyWith(color: secondary),
      labelSmall: style(
        11,
        FontWeight.w500,
        height: 14 / 11,
      ).copyWith(color: secondary),
    ).apply(bodyColor: primary, displayColor: primary);
  }

  /// Spotify dark scheme — also used for the light slot so the app stays in
  /// dark mode regardless of the system setting.
  static ThemeData get light => dark;

  static ThemeData get dark => _build(
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: SpotifyColors.accent,
      onPrimary: Colors.black,
      primaryContainer: SpotifyColors.accent,
      onPrimaryContainer: Colors.black,
      secondary: SpotifyColors.surface,
      onSecondary: SpotifyColors.textPrimary,
      secondaryContainer: SpotifyColors.surface,
      onSecondaryContainer: SpotifyColors.textSubdued,
      tertiary: SpotifyColors.accent,
      onTertiary: Colors.black,
      tertiaryContainer: SpotifyColors.accent,
      onTertiaryContainer: Colors.black,
      error: SpotifyColors.danger,
      onError: Colors.white,
      surface: SpotifyColors.background,
      onSurface: SpotifyColors.textPrimary,
      onSurfaceVariant: SpotifyColors.textSubdued,
      surfaceContainerHighest: SpotifyColors.surface,
      surfaceContainerHigh: SpotifyColors.surface,
      surfaceContainer: SpotifyColors.surface,
      surfaceContainerLow: SpotifyColors.surface,
      surfaceContainerLowest: SpotifyColors.background,
      outline: SpotifyColors.border,
      outlineVariant: SpotifyColors.borderStrong,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: SpotifyColors.textPrimary,
      onInverseSurface: SpotifyColors.background,
      inversePrimary: SpotifyColors.accent,
    ),
    textTheme: _textTheme(SpotifyColors.textPrimary, SpotifyColors.textSubdued),
  );

  // -----------------------------------------------------------------------
  // Shared component styling
  // -----------------------------------------------------------------------
  static ThemeData _build({
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    // Focused inputs use a brighter take on their resting border rather than
    // the loud accent color.
    final focusBorder = Color.lerp(
      scheme.outlineVariant,
      scheme.onSurface,
      0.5,
    )!;

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: SpotifyColors.background,
        foregroundColor: SpotifyColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: SpotifyColors.textPrimary),
        toolbarHeight: 56,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SpotifyColors.surface,
        elevation: 0,
        height: 64,
        indicatorColor: SpotifyColors.accent.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? SpotifyColors.accent : SpotifyColors.textSubdued,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? SpotifyColors.accent : SpotifyColors.textSubdued,
          );
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: SpotifyColors.background,
        indicatorColor: SpotifyColors.accent,
        selectedIconTheme: const IconThemeData(
          color: SpotifyColors.textPrimary,
        ),
        unselectedIconTheme: const IconThemeData(
          color: SpotifyColors.textSubdued,
        ),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: SpotifyColors.textPrimary,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: SpotifyColors.textSubdued,
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        shape: const Border(),
      ),

      cardTheme: CardThemeData(
        color: SpotifyColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: SpotifyColors.border),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: SpotifyColors.border,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: SpotifyColors.textSubdued,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SpotifyColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SpotifyColors.borderStrong,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SpotifyColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SpotifyColors.borderStrong,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpotifyColors.accent,
          disabledForegroundColor: SpotifyColors.textSubdued,
          side: const BorderSide(color: SpotifyColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SpotifyColors.accent,
          disabledForegroundColor: SpotifyColors.textSubdued,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: SpotifyColors.textSubdued,
          padding: const EdgeInsets.all(8),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SpotifyColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpotifyColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: SpotifyColors.textSubdued.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpotifyColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpotifyColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: focusBorder, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpotifyColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SpotifyColors.danger, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: SpotifyColors.surface,
        selectedColor: SpotifyColors.accent,
        labelStyle: textTheme.labelMedium,
        side: const BorderSide(color: SpotifyColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      badgeTheme: const BadgeThemeData(
        backgroundColor: SpotifyColors.danger,
        textColor: Colors.white,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: SpotifyColors.textPrimary,
        unselectedLabelColor: SpotifyColors.textSubdued,
        indicatorColor: SpotifyColors.textPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: SpotifyColors.surface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: SpotifyColors.textPrimary,
        ),
        actionTextColor: SpotifyColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: SpotifyColors.border),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: SpotifyColors.surface,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: SpotifyColors.textPrimary,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: SpotifyColors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: SpotifyColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: SpotifyColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: textTheme.bodyMedium,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return SpotifyColors.textSubdued;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SpotifyColors.accent;
          }
          return SpotifyColors.borderStrong;
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SpotifyColors.accent,
        linearTrackColor: SpotifyColors.border,
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: SpotifyColors.accent,
        thumbColor: SpotifyColors.accent,
        inactiveTrackColor: SpotifyColors.border,
        overlayColor: Color(0x3325A10C),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: SpotifyColors.textPrimary,
        selectionColor: SpotifyColors.textPrimary.withValues(alpha: 0.25),
        selectionHandleColor: SpotifyColors.textPrimary,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
