import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// The app is dark-only: the whole look depends on the black canvas.
ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.violet,
    onPrimary: AppColors.white,
    secondary: AppColors.coral,
    onSecondary: AppColors.white,
    error: AppColors.coral,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceHigh,
    outline: AppColors.line,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    splashFactory: NoSplash.splashFactory, // NeoPOP presses, not ripples
    highlightColor: Colors.transparent,
    textTheme: TextTheme(
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      titleLarge: AppText.heading,
      titleMedium: AppText.subheading,
      labelLarge: AppText.button,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppText.subheading,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: AppText.body,
      actionTextColor: AppColors.violet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.violet,
      selectionHandleColor: AppColors.violet,
    ),
  );
}
