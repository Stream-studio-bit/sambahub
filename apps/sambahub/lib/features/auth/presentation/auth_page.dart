// CHANGELOG
// - Adicionado background full-bleed com assets/images/background.png (Stack + scrim escuro para legibilidade)
// - Logo trocada de ícone genérico (Icons.graphic_eq_rounded) para assets/icons/icon.png
// - "Samba" agora sempre branco e "Hub" sempre AppColors.orange (antes dependia do parâmetro `light`)
// - Textos do painel de marca (desktop) e do cabeçalho compacto (mobile) forçados para branco,
//   por estarem agora sobre a imagem de fundo
// - Card de formulário (AppCard) e seus badges/labels internos (SegmentedButton, dropdown, feedback)
//   NÃO foram alterados — mantêm as cores originais, conforme solicitado
// - Assumido que os assets já estão declarados em pubspec.yaml em assets/icons/icon.png e
//   assets/images/background.png; caso os caminhos reais sejam diferentes, ajustar as duas
//   constantes _kLogoAsset / _kBackgroundAsset abaixo

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

enum _AuthMode { signIn, signUp }

enum _ProfileType { venue, producer, group }

const String _kLogoAsset = 'assets/icons/icon.png';
const String _kBackgroundAsset = 'assets/images/background.png';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  _ProfileType _profileType = _ProfileType.venue;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  bool get _isSignUp => _mode == _AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.wineDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _kBackgroundAsset,
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 820;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontalMobile,
                    vertical: AppSpacing.xxxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 960 : AppSpacing.formMaxWidth,
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _buildBrandPanel(context)),
                                const SizedBox(width: AppSpacing.section),
                                SizedBox(
                                    width: 420,
                                    child: _buildFormCard(context)),
                              ],
                            )
                          : _buildMobileContent(context),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCompactBrand(context),
        const SizedBox(height: AppSpacing.xxxl),
        _buildFormCard(context),
      ],
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrandMark(),
          const SizedBox(height: AppSpacing.section),
          Text(
            'Sua roda começa\naqui.',
            style: AppTypography.textTheme.displaySmall?.copyWith(
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Organize seus eventos, venda ingressos e mantenha o samba em movimento.',
            style: AppTypography.textTheme.bodyLarge?.copyWith(
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBrand(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrandMark(),
        const SizedBox(height: AppSpacing.xxxl),
        Text(
          _isSignUp ? 'Comece sua roda.' : 'Que bom ter você por aqui.',
          style: AppTypography.textTheme.headlineLarge?.copyWith(
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _isSignUp
              ? 'Crie sua conta e leve seu samba mais longe.'
              : 'Entre para continuar cuidando do seu samba.',
          style: AppTypography.textTheme.bodyLarge?.copyWith(
            color: AppColors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBrandMark() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _kLogoAsset,
          width: 34,
          height: 34,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: AppSpacing.sm),
        RichText(
          text: TextSpan(
            style: AppTypography.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            children: [
              const TextSpan(
                text: 'Samba',
                style: TextStyle(color: AppColors.white),
              ),
              TextSpan(
                text: 'Hub',
                style: TextStyle(color: AppColors.orange),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSwitch(),
            const SizedBox(height: AppSpacing.xl),
            if (_isSignUp) ...[
              AppInput(
                label: 'Nome',
                hintText: 'Seu nome ou nome da casa',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.person_outline),
                validator: _requiredValidator('Informe seu nome.'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildProfileSelector(),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppInput(
              label: 'E-mail',
              hintText: 'voce@exemplo.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.mail_outline),
              autofillHints: const [AutofillHints.email],
              validator: _emailValidator,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppInput(
              label: 'Senha',
              hintText: 'Mínimo de 6 caracteres',
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              validator: _passwordValidator,
            ),
            if (!_isSignUp) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      _isSubmitting ? null : () => context.go('/recuperar-senha'),
                  child: const Text('Esqueci minha senha'),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildFeedback(
                message: _errorMessage!,
                color: AppColors.error,
                background: AppColors.errorSurface,
                icon: Icons.error_outline,
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildFeedback(
                message: _successMessage!,
                color: AppColors.success,
                background: AppColors.successSurface,
                icon: Icons.check_circle_outline,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _isSignUp ? 'Criar minha conta' : 'Entrar no SambaHub',
              size: AppButtonSize.large,
              isFullWidth: true,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _isSignUp
                  ? 'Ao continuar, você concorda com os termos de uso.'
                  : 'Acesso seguro protegido pelo Supabase Auth.',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSelector() {
    return DropdownButtonFormField<_ProfileType>(
      initialValue: _profileType,
      decoration: const InputDecoration(
        labelText: 'Perfil de atuação',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: const [
        DropdownMenuItem(
          value: _ProfileType.venue,
          child: Text('Casa noturna / local'),
        ),
        DropdownMenuItem(
          value: _ProfileType.producer,
          child: Text('Produtor / produtora'),
        ),
        DropdownMenuItem(
          value: _ProfileType.group,
          child: Text('Grupo de samba'),
        ),
      ],
      onChanged: _isSubmitting
          ? null
          : (value) => setState(
                () => _profileType = value ?? _ProfileType.venue,
              ),
    );
  }

  Widget _buildModeSwitch() {
    return SegmentedButton<_AuthMode>(
      segments: const [
        ButtonSegment(
          value: _AuthMode.signIn,
          label: Text('Entrar'),
          icon: Icon(Icons.login_rounded),
        ),
        ButtonSegment(
          value: _AuthMode.signUp,
          label: Text('Criar conta'),
          icon: Icon(Icons.person_add_alt_1_rounded),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: _isSubmitting
          ? null
          : (selection) {
              setState(() {
                _mode = selection.first;
                _errorMessage = null;
                _successMessage = null;
              });
            },
      showSelectedIcon: false,
    );
  }

  Widget _buildFeedback({
    required String message,
    required Color color,
    required Color background,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
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
      final service = SupabaseService.instance;
      AuthResponse response;

      if (_isSignUp) {
        response = await service.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
          profileType: _profileType.name,
        );

        if (!mounted) return;
        setState(() {
          _successMessage = response.session == null
              ? 'Conta criada. Verifique seu e-mail para confirmar o acesso.'
              : 'Conta criada com sucesso.';
        });
      } else {
        response = await service.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (!mounted) return;
        setState(() {
          _successMessage = response.session == null
              ? 'Acesso realizado. A sessão será atualizada em instantes.'
              : 'Acesso realizado com sucesso.';
        });
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyAuthError(error));
    } on SupabaseConfigurationException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível concluir agora. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  FormFieldValidator<String> _requiredValidator(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu e-mail.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Digite um e-mail válido.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Informe sua senha.';
    if (value.length < 6) return 'A senha deve ter pelo menos 6 caracteres.';
    return null;
  }

  String _friendlyAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar.';
    }
    if (message.contains('user already registered')) {
      return 'Este e-mail já possui uma conta.';
    }
    if (message.contains('password')) {
      return 'A senha não atende aos requisitos de segurança.';
    }
    return 'Não foi possível autenticar. Tente novamente.';
  }
}