import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'slack_colors.dart';

/// Application themes modeled after the Slack mobile app.
///
/// Use [AppTheme.light] / [AppTheme.dark] with `MaterialApp.theme` and
/// `MaterialApp.darkTheme`. Component themes (AppBar, buttons, chips,
/// navigation, etc.) are tuned to Slack's aubergine chrome and system type.
/// The type scale follows WhatsApp mobile's compact sizes.
abstract final class AppTheme {
  /// Default typeface for the whole app. `null` lets Flutter fall back to the
  /// platform's system font family (Roboto on Android, SF on iOS, etc.).
  static const String? fontFamily = null;

  /// Brand typeface, bundled from `assets/fonts`. Used only for the app name /
  /// wordmark on the splash, loading and login screens.
  static const String brandFontFamily = 'Montserrat';

  /// Wordmark style for the launch/splash and loading screens.
  static TextStyle get splashWordmarkStyle => const TextStyle(
    fontFamily: brandFontFamily,
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
      displaySmall: style(20, FontWeight.w500, height: 26 / 20),
      headlineLarge: style(20, FontWeight.w600, height: 26 / 20),
      headlineMedium: style(18, FontWeight.w600, height: 24 / 18),
      headlineSmall: style(17, FontWeight.w500, height: 22 / 17),
      titleLarge: style(16, FontWeight.w500, height: 21 / 16),
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
      labelLarge: style(15, FontWeight.w600, height: 20 / 15),
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

  // -----------------------------------------------------------------------
  // Light theme (default Slack mobile look)
  // -----------------------------------------------------------------------
  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: SlackColors.accentGreen,
      onPrimary: Colors.white,
      primaryContainer: SlackColors.blueLight,
      onPrimaryContainer: Colors.white,
      secondary: SlackColors.aubergine,
      onSecondary: Colors.white,
      secondaryContainer: SlackColors.lightSurfaceSecondary,
      onSecondaryContainer: SlackColors.purple,
      tertiary: SlackColors.green,
      onTertiary: Colors.white,
      tertiaryContainer: SlackColors.green,
      onTertiaryContainer: Colors.white,
      error: SlackColors.red,
      onError: Colors.white,
      surface: SlackColors.lightBackground,
      onSurface: SlackColors.lightTextPrimary,
      onSurfaceVariant: SlackColors.lightTextSecondary,
      surfaceContainerHighest: SlackColors.lightSurface,
      surfaceContainerHigh: SlackColors.lightSurface,
      surfaceContainer: SlackColors.lightSurface,
      surfaceContainerLow: SlackColors.lightSurface,
      surfaceContainerLowest: SlackColors.lightBackground,
      outline: SlackColors.lightBorder,
      outlineVariant: SlackColors.lightBorderStrong,
      shadow: Colors.black,
      scrim: Colors.black38,
      inverseSurface: SlackColors.aubergine,
      onInverseSurface: SlackColors.lightTextOnAubergine,
      inversePrimary: SlackColors.aubergineDark,
    ),
    textTheme: _textTheme(
      SlackColors.lightTextPrimary,
      SlackColors.lightTextSecondary,
    ),
  );

  // -----------------------------------------------------------------------
  // Dark theme
  // -----------------------------------------------------------------------
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: SlackColors.accentGreen,
      onPrimary: Colors.white,
      primaryContainer: SlackColors.blue,
      onPrimaryContainer: Colors.white,
      secondary: SlackColors.purple,
      onSecondary: Colors.white,
      secondaryContainer: SlackColors.darkSurfaceSecondary,
      onSecondaryContainer: Color(0xFFE8D4E8),
      tertiary: SlackColors.green,
      onTertiary: Colors.white,
      tertiaryContainer: SlackColors.greenDark,
      onTertiaryContainer: Colors.white,
      error: SlackColors.red,
      onError: Colors.white,
      surface: SlackColors.darkBackground,
      onSurface: SlackColors.darkTextPrimary,
      onSurfaceVariant: SlackColors.darkTextSecondary,
      surfaceContainerHighest: SlackColors.darkSurface,
      surfaceContainerHigh: SlackColors.darkSurface,
      surfaceContainer: SlackColors.darkSurface,
      surfaceContainerLow: SlackColors.darkSurface,
      surfaceContainerLowest: SlackColors.darkBackground,
      outline: SlackColors.darkBorder,
      outlineVariant: SlackColors.darkBorderStrong,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: SlackColors.darkTextPrimary,
      onInverseSurface: SlackColors.darkBackground,
      inversePrimary: SlackColors.aubergine,
    ),
    textTheme: _textTheme(
      SlackColors.darkTextPrimary,
      SlackColors.darkTextSecondary,
    ),
  );

  // -----------------------------------------------------------------------
  // Shared component styling
  // -----------------------------------------------------------------------
  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    final isLight = brightness == Brightness.light;
    final disabled = isLight
        ? const Color(0xFF9B9A97)
        : const Color(0xFF6B6C70);

    // Focused inputs use a brighter take on their resting border rather than
    // the loud accent color.
    final focusBorder = Color.lerp(scheme.outlineVariant, scheme.onSurface, 0.5)!;

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: SlackColors.aubergine,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 56,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight
            ? SlackColors.lightBackground
            : SlackColors.darkSurface,
        elevation: 0,
        height: 64,
        indicatorColor: isLight
            ? const Color(0xFFE8F0FA)
            : const Color(0xFF1D3A52),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? SlackColors.blue : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? SlackColors.blue : scheme.onSurfaceVariant,
          );
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: SlackColors.aubergine,
        indicatorColor: SlackColors.blue,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(
          color: isLight
              ? SlackColors.lightTextSidebarInactive
              : const Color(0xFFC9B3CB),
        ),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: Colors.white,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: isLight
              ? SlackColors.lightTextSidebarInactive
              : const Color(0xFFC9B3CB),
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: SlackColors.aubergine,
        elevation: 0,
        shape: const Border(),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SlackColors.accentGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: disabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SlackColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: disabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SlackColors.blue,
          disabledForegroundColor: disabled,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SlackColors.blue,
          disabledForegroundColor: disabled,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          padding: const EdgeInsets.all(8),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SlackColors.greenDark,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : SlackColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: focusBorder, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SlackColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SlackColors.red, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? SlackColors.lightSurface
            : SlackColors.darkSurface,
        selectedColor: SlackColors.blue,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      badgeTheme: BadgeThemeData(
        backgroundColor: SlackColors.red,
        textColor: Colors.white,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: SlackColors.lightTextSidebarInactive,
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight
            ? SlackColors.lightTextPrimary
            : SlackColors.darkSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? Colors.white : SlackColors.darkTextPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? SlackColors.lightTextPrimary : SlackColors.darkSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: textTheme.bodyMedium,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isLight ? const Color(0xFF616061) : const Color(0xFF9B9A97);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return SlackColors.accentGreen;
          return isLight ? const Color(0xFFDDDDDD) : const Color(0xFF454548);
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SlackColors.blue,
        linearTrackColor: SlackColors.lightBorder,
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: SlackColors.blue,
        thumbColor: SlackColors.blue,
        inactiveTrackColor: SlackColors.lightBorder,
        overlayColor: Color(0x331264A3),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.onSurface,
        selectionColor: scheme.onSurface.withValues(alpha: 0.25),
        selectionHandleColor: scheme.onSurface,
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
