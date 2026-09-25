import 'package:flutter/material.dart';

/// Raios oficiais de borda do design system SambaHub.
///
/// Os componentes devem utilizar estes tokens em vez de declarar valores
/// arbitrários com BorderRadius.circular().
abstract final class AppRadii {
  static const xs = BorderRadius.all(Radius.circular(8));
  static const sm = BorderRadius.all(Radius.circular(12));
  static const md = BorderRadius.all(Radius.circular(16));
  static const lg = BorderRadius.all(Radius.circular(20));
  static const xl = BorderRadius.all(Radius.circular(28));
  static const pill = BorderRadius.all(Radius.circular(999));

  static const topSheet = BorderRadius.vertical(
    top: Radius.circular(28),
  );

  static const card = md;
  static const button = sm;
  static const input = sm;
  static const chip = pill;
}
