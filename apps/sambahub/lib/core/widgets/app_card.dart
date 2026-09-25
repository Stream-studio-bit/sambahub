import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Superfície reutilizável do SambaHub.
///
/// Use [onTap] somente quando o card representar uma ação ou navegação. Para
/// conteúdo puramente visual, mantenha [onTap] nulo para preservar semântica.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.backgroundColor = AppColors.paper,
    this.borderColor = AppColors.line,
    this.borderRadius = 12,
    this.elevation = 0,
    this.shadowColor = const Color(0x14000000),
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final double elevation;
  final Color shadowColor;
  final Clip clipBehavior;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: backgroundColor,
      elevation: elevation,
      shadowColor: shadowColor,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.peach.withValues(alpha: .65),
        highlightColor: AppColors.peach.withValues(alpha: .28),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    final content = margin == EdgeInsets.zero
        ? card
        : Padding(
            padding: margin,
            child: card,
          );

    if (semanticLabel == null || semanticLabel!.trim().isEmpty) {
      return content;
    }

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: content,
    );
  }
}
