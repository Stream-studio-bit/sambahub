import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.wineDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontalMobile,
              vertical: AppSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Esqueceu sua senha?',
                        style: AppTypography.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Informe seu e-mail para receber o link de recuperação.',
                        style: AppTypography.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppInput(
                        label: 'E-mail',
                        hintText: 'voce@exemplo.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(Icons.mail_outline),
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _submit(),
                        validator: _emailValidator,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _errorMessage!,
                          style: AppTypography.textTheme.bodySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _successMessage!,
                          style: AppTypography.textTheme.bodySmall
                              ?.copyWith(color: AppColors.success),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Enviar link de recuperação',
                        size: AppButtonSize.large,
                        isFullWidth: true,
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: () => context.go('/auth'),
                        child: const Text('Voltar para o login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      await SupabaseService.instance.resetPasswordForEmail(
        _emailController.text,
      );
      if (!mounted) return;
      setState(() {
        _successMessage =
            'Se o e-mail existir, você receberá um link de recuperação em instantes.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível enviar agora. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu e-mail.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Digite um e-mail válido.';
    }
    return null;
  }
}