import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Campo de texto base do SambaHub.
///
/// Mantém a aparência dos formulários consistente e deixa a validação de
/// domínio para o controller ou Form da feature.
class AppInput extends StatelessWidget {
  const AppInput({
    required this.label,
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.errorText,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.semanticHint,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? semanticHint;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final input = TextFormField(
      controller: controller,
      focusNode: focusNode,
      initialValue: controller == null ? initialValue : null,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      maxLines: obscureText ? 1 : maxLines,
      minLines: maxLines == 1 ? null : minLines,
      maxLength: maxLength,
      autofillHints: autofillHints,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: 14,
        color: AppColors.ink,
      ),
      cursorColor: AppColors.orange,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon == null
            ? null
            : IconTheme(
                data: const IconThemeData(
                  size: 19,
                  color: AppColors.muted,
                ),
                child: prefixIcon!,
              ),
        suffixIcon: suffixIcon == null
            ? null
            : IconTheme(
                data: const IconThemeData(
                  size: 19,
                  color: AppColors.muted,
                ),
                child: suffixIcon!,
              ),
        counterStyle: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: 11,
          color: AppColors.muted,
        ),
      ),
    );

    return Semantics(
      textField: true,
      label: label,
      hint: semanticHint ?? hintText,
      enabled: enabled,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: input,
      ),
    );
  }
}
