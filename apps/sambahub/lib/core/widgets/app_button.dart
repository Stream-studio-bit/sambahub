import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outline,
  text,
  destructive,
}

enum AppButtonSize {
  small,
  medium,
  large,
}

/// Botão base do SambaHub.
///
/// Centraliza os estados visuais e comportamentais usados em CTAs públicos,
/// formulários administrativos e ações de checkout. Não deve conter regra de
/// negócio: a tela ou controller decide o que acontece no [onPressed].
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    super.key,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool isFullWidth;
  final String? tooltip;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final button = switch (variant) {
      AppButtonVariant.primary => _buildElevated(
          context,
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.muted,
        ),
      AppButtonVariant.secondary => _buildElevated(
          context,
          backgroundColor: AppColors.wine,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.muted,
        ),
      AppButtonVariant.destructive => _buildElevated(
          context,
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.muted,
        ),
      AppButtonVariant.outline => _buildOutlined(context),
      AppButtonVariant.text => _buildText(context),
    };

    final constrainedButton =
        isFullWidth ? SizedBox(width: double.infinity, child: button) : button;

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return constrainedButton;
    }

    return Tooltip(
      message: tooltip!,
      child: constrainedButton,
    );
  }

  Widget _buildElevated(
    BuildContext context, {
    required Color backgroundColor,
    required Color foregroundColor,
    required Color disabledBackgroundColor,
    required Color disabledForegroundColor,
  }) {
    return ElevatedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(0, _height),
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: disabledBackgroundColor,
        disabledForegroundColor: disabledForegroundColor,
        elevation: 0,
        shadowColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: _textStyle,
      ),
      child: _content(foregroundColor),
    );
  }

  Widget _buildOutlined(BuildContext context) {
    return OutlinedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, _height),
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
        foregroundColor: AppColors.wine,
        disabledForegroundColor: AppColors.muted,
        side: BorderSide(
          color: _isDisabled ? AppColors.line : AppColors.wine,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: _textStyle,
      ),
      child: _content(AppColors.wine),
    );
  }

  Widget _buildText(BuildContext context) {
    return TextButton(
      onPressed: _isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(0, _height),
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding / 2),
        foregroundColor: AppColors.wine,
        disabledForegroundColor: AppColors.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: _textStyle,
      ),
      child: _content(AppColors.wine),
    );
  }

  Widget _content(Color foregroundColor) {
    if (isLoading) {
      return SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          IconTheme(
            data: IconThemeData(size: _iconSize),
            child: leading!,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          IconTheme(
            data: IconThemeData(size: _iconSize),
            child: trailing!,
          ),
        ],
      ],
    );
  }

  double get _height => switch (size) {
        AppButtonSize.small => 40,
        AppButtonSize.medium => 48,
        AppButtonSize.large => 52,
      };

  double get _horizontalPadding => switch (size) {
        AppButtonSize.small => 12,
        AppButtonSize.medium => 16,
        AppButtonSize.large => 20,
      };

  double get _iconSize => switch (size) {
        AppButtonSize.small => 16,
        AppButtonSize.medium => 18,
        AppButtonSize.large => 18,
      };

  double get _radius => switch (size) {
        AppButtonSize.small => 7,
        AppButtonSize.medium => 8,
        AppButtonSize.large => 8,
      };

  TextStyle get _textStyle => switch (size) {
        AppButtonSize.small => const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        AppButtonSize.medium => const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        AppButtonSize.large => const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
      };
}
