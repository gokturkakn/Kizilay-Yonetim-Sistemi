import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 açık tema — docs/UX.md §1.
ThemeData buildAppTheme() {
  const textTheme = TextTheme(
    headlineSmall: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w600, height: 32 / 24),
    titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w600, height: 28 / 20),
    titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, height: 24 / 16),
    titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14),
    bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16),
    bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14),
    bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12),
    labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14),
  );

  final colorScheme = const ColorScheme.light(
    primary: kPrimary,
    onPrimary: kOnPrimary,
    primaryContainer: kPrimaryContainer,
    onPrimaryContainer: kPrimaryDark,
    surface: kSurface,
    onSurface: kTextPrimary,
    error: kError,
    onError: Colors.white,
    errorContainer: kErrorContainer,
    onErrorContainer: kError,
    outline: kBorder,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBackground,
    textTheme: textTheme.apply(
      bodyColor: kTextPrimary,
      displayColor: kTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: kOnPrimary,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: kOnPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r12),
        side: const BorderSide(color: kBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(color: kBorder, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: kOnPrimary,
        minimumSize: const Size(48, 48),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
        minimumSize: const Size(48, 48),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimary,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r8),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r8),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r8),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r8),
        borderSide: const BorderSide(color: kError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r8),
        borderSide: const BorderSide(color: kError, width: 2),
      ),
      filled: true,
      fillColor: kSurface,
      labelStyle: const TextStyle(color: kTextSecondary),
      hintStyle: const TextStyle(color: kTextDisabled),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kPrimaryContainer,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? kPrimary
              : kTextSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? kPrimary
              : kTextSecondary,
        );
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: kOnPrimary,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kOnPrimary,
      unselectedLabelColor: Color(0xFFF5C2C5),
      indicatorColor: kOnPrimary,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: kPrimary),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r12)),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: kTextPrimary),
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: kTextPrimary),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(side: BorderSide(color: kBorder)),
      backgroundColor: kSurface,
      selectedColor: kPrimaryContainer,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: kTextPrimary,
      ),
      showCheckmark: false,
    ),
  );
}
