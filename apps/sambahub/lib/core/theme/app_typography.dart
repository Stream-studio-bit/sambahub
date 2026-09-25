import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Hierarquia tipográfica do SambaHub.
///
/// Bricolage Grotesque é usada em marca e títulos editoriais. DM Sans é usada
/// em leitura, formulários, preços e elementos operacionais.
abstract final class AppTypography {
  static const displayFamily = 'Bricolage Grotesque';
  static const bodyFamily = 'DM Sans';

  static TextTheme get textTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 72,
        fontWeight: FontWeight.w600,
        letterSpacing: -5.6,
        height: .9,
        color: AppColors.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 56,
        fontWeight: FontWeight.w600,
        letterSpacing: -4.2,
        height: .92,
        color: AppColors.ink,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFamily,
        fontSize: 44,
        fontWeight: FontWeight.w600,
        letterSpacing: -3.2,
        height: .94,
        color: AppColors.ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 38,
        fontWeight: FontWeight.w600,
        letterSpacing: -2.2,
        height: 1,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.4,
        height: 1.05,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -.8,
        height: 1.1,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -.5,
        height: 1.15,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -.1,
        height: 1.25,
        color: AppColors.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .05,
        height: 1.25,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -.1,
        height: 1.55,
        color: AppColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.45,
        color: AppColors.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: .05,
        height: 1.4,
        color: AppColors.muted,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.15,
        color: AppColors.ink,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .3,
        height: 1.2,
        color: AppColors.ink,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFamily,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.2,
        color: AppColors.muted,
      ),
    );
  }
}
