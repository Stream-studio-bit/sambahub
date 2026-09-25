/// Escala de espaçamento do SambaHub.
///
/// A escala usa múltiplos de 4 para manter ritmo visual consistente entre
/// mobile, tablet e Web. Prefira estes tokens a valores soltos nas telas.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double section = 64;
  static const double sectionLarge = 88;

  static const double pageHorizontalMobile = 16;
  static const double pageHorizontalTablet = 24;
  static const double pageHorizontalDesktop = 32;
  static const double contentMaxWidth = 1160;
  static const double formMaxWidth = 520;

  static const double touchTarget = 48;
  static const double compactTouchTarget = 40;
}
