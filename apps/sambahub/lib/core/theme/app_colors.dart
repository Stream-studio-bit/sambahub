import 'package:flutter/material.dart';

/// Paleta oficial do SambaHub.
///
/// As telas não devem declarar cores de marca diretamente. Use [AppColors]
/// ou as cores semânticas expostas pelo [AppTheme].
abstract final class AppColors {
  static const ink = Color(0xFF261814);
  static const muted = Color(0xFF846F68);
  static const cream = Color(0xFFF8F4EF);
  static const paper = Color(0xFFFFFDFA);
  static const wine = Color(0xFF8C1D2C);
  static const wineDeep = Color(0xFF5A1320);
  static const orange = Color(0xFFE4572E);
  static const gold = Color(0xFFDCAE5A);
  static const peach = Color(0xFFFBE9DC);
  static const line = Color(0xFFEADFD5);

  static const success = Color(0xFF287A46);
  static const successSurface = Color(0xFFEAF6ED);
  static const warning = Color(0xFF9A6715);
  static const warningSurface = Color(0xFFFFF5DE);
  static const error = Color(0xFFB42318);
  static const errorSurface = Color(0xFFFFECEA);
  static const info = Color(0xFF305E76);
  static const infoSurface = Color(0xFFEAF4F8);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);

  static const heroOverlay = Color(0xCC130805);
  static const darkSurface = Color(0xFF35121A);
  static const darkMuted = Color(0xFFE5C2AE);
}
