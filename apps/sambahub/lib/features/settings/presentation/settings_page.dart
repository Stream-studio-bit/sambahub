// CHANGELOG
// 2026-09-21: Adicionada seção Mercado Pago (Prompt Mestre, item 12) —
// _MercadoPagoSection, exibida tanto no formulário editável quanto na visão
// somente leitura (o status é sempre visível; os botões de
// conectar/reconectar/desconectar só aparecem para quem pode gerenciar,
// mesma regra de canEdit já usada no resto da página). É
// ConsumerStatefulWidget com WidgetsBindingObserver: o OAuth roda no
// navegador fora do app (mp-marketplace-oauth), então ao voltar ao primeiro
// plano (AppLifecycleState.resumed) a seção chama
// mercadoPagoConnectionProvider(tenantId).notifier.refresh() para refletir o
// resultado do callback sem exigir pull-to-refresh manual. Erros de
// connect()/disconnect() (SettingsException) aparecem em SnackBar, com botão
// desabilitado durante a chamada (_working).
//
// 2026-09-19: P11 (Trilha G) — SettingsPage reescrita sobre o controller novo.
// - Formulário com Form + SettingsValidation (nome, e-mail, telefone). Antes
//   nada era validado.
// - Permissão: só owner/admin editam (a RLS de UPDATE em tenants exige
//   can_manage_tenant). Outros papéis veem os dados em modo somente leitura,
//   com aviso. O papel vem de settingsRoleProvider.
// - Salvar: a página controla o estado "salvando" (botão e switches
//   desabilitados) e faz try/catch, mostrando SettingsException no SnackBar. O
//   formulário não é mais desmontado durante o save, então nada digitado se
//   perde, e uma falha não vira tela de erro.
// - Após salvar, o controller troca o state pelos dados do banco e o
//   formulário se sincroniza (didUpdateWidget): a atualização aparece na hora.
// - Erro de carga mostra a mensagem e "Tentar novamente".
// - Exibe slug, status, fuso horário e moeda como informação (somente leitura;
//   não há seletor de fuso). Sem campos novos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../data/settings_repository.dart';
import '../domain/mercadopago_connection.dart';
import '../domain/settings_permissions.dart';
import '../domain/settings_validation.dart';
import '../domain/tenant_settings.dart';
import 'settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({required this.tenantId, super.key});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider(tenantId));
    final role = ref.watch(settingsRoleProvider(tenantId));

    void retry() =>
        ref.read(settingsControllerProvider(tenantId).notifier).refresh();

    return Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: settings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                _ErrorState(message: _message(error), onRetry: retry),
            data: (value) => role.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    _ErrorState(message: _message(error), onRetry: retry),
                data: (roleValue) {
                  final canEdit = roleValue != null &&
                      SettingsPermissions.can(
                          roleValue, SettingsPermission.editOrganization);
                  return canEdit
                      ? _SettingsForm(tenantId: tenantId, settings: value)
                      : _ReadOnlySettings(tenantId: tenantId, settings: value);
                })));
  }
}

String _message(Object error) => error is SettingsException
    ? error.message
    : 'Não foi possível carregar as configurações.';

String _statusLabel(String status) => switch (status) {
      'active' => 'Ativa',
      'suspended' => 'Suspensa',
      'archived' => 'Arquivada',
      _ => status
    };

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.tenantId, required this.settings});
  final String tenantId;
  final TenantSettings settings;
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _legalName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late bool _notifications;
  late bool _checkin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _legalName = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _fill(widget.settings);
  }

  @override
  void didUpdateWidget(covariant _SettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Novos dados vindos do banco (após salvar): refletir na hora.
    if (!identical(oldWidget.settings, widget.settings)) {
      _fill(widget.settings);
    }
  }

  void _fill(TenantSettings settings) {
    _name.text = settings.name;
    _legalName.text = settings.legalName ?? '';
    _email.text = settings.email ?? '';
    _phone.text = settings.phone ?? '';
    _notifications = settings.notificationsEnabled;
    _checkin = settings.checkinEnabled;
  }

  @override
  void dispose() {
    _name.dispose();
    _legalName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.section),
          children: [
            Text('Identidade da organização',
                style: AppTypography.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
                child: Column(children: [
              AppInput(
                  label: 'Nome público',
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  validator: SettingsValidation.name),
              const SizedBox(height: AppSpacing.sm),
              AppInput(
                  label: 'Razão social',
                  controller: _legalName,
                  textInputAction: TextInputAction.next),
              const SizedBox(height: AppSpacing.sm),
              AppInput(
                  label: 'E-mail',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: SettingsValidation.email),
              const SizedBox(height: AppSpacing.sm),
              AppInput(
                  label: 'Telefone',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: SettingsValidation.phone)
            ])),
            const SizedBox(height: AppSpacing.lg),
            Text('Preferências', style: AppTypography.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
                child: Column(children: [
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notificações operacionais'),
                  subtitle: const Text(
                      'Receber atualizações de pedidos e pagamentos'),
                  value: _notifications,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _notifications = value)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Check-in habilitado'),
                  subtitle: const Text(
                      'Permitir validação de ingressos nesta organização'),
                  value: _checkin,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _checkin = value))
            ])),
            const SizedBox(height: AppSpacing.lg),
            Text('Mercado Pago', style: AppTypography.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            _MercadoPagoSection(tenantId: widget.tenantId, canManage: true),
            const SizedBox(height: AppSpacing.lg),
            _InfoCard(settings: widget.settings),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: 'Salvar configurações',
                isFullWidth: true,
                isLoading: _saving,
                onPressed: _saving ? null : _save)
          ]),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsControllerProvider(widget.tenantId).notifier).save(
          name: _name.text,
          legalName: _legalName.text,
          email: _email.text,
          phone: _phone.text,
          timezone: widget.settings.timezone,
          notificationsEnabled: _notifications,
          checkinEnabled: _checkin);
      _snack('Configurações salvas.');
    } catch (error) {
      _snack(error is SettingsException
          ? error.message
          : 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReadOnlySettings extends StatelessWidget {
  const _ReadOnlySettings({required this.tenantId, required this.settings});
  final String tenantId;
  final TenantSettings settings;

  @override
  Widget build(BuildContext context) {
    String orDash(String? value) =>
        value == null || value.isEmpty ? '—' : value;
    return ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.section),
        children: [
          AppCard(
              child: Text(
                  'Apenas proprietários e administradores podem alterar as configurações.',
                  style: AppTypography.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted))),
          const SizedBox(height: AppSpacing.lg),
          Text('Identidade da organização',
              style: AppTypography.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Nome público: ${settings.name}'),
                Text('Razão social: ${orDash(settings.legalName)}'),
                Text('E-mail: ${orDash(settings.email)}'),
                Text('Telefone: ${orDash(settings.phone)}'),
              ])),
          const SizedBox(height: AppSpacing.lg),
          Text('Preferências', style: AppTypography.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    'Notificações operacionais: ${settings.notificationsEnabled ? 'ativadas' : 'desativadas'}'),
                Text(
                    'Check-in: ${settings.checkinEnabled ? 'habilitado' : 'desabilitado'}'),
              ])),
          const SizedBox(height: AppSpacing.lg),
          Text('Mercado Pago', style: AppTypography.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          _MercadoPagoSection(tenantId: tenantId, canManage: false),
          const SizedBox(height: AppSpacing.lg),
          _InfoCard(settings: settings),
        ]);
  }
}

/// Status da conexão Mercado Pago do tenant e, quando [canManage] é true, os
/// botões de conectar/reconectar/desconectar (Prompt Mestre, item 12).
/// Observa o ciclo de vida do app porque o OAuth roda no navegador, fora do
/// app: ao voltar (resumed), recarrega o status para refletir o resultado do
/// callback sem exigir ação manual do usuário.
class _MercadoPagoSection extends ConsumerStatefulWidget {
  const _MercadoPagoSection({required this.tenantId, required this.canManage});
  final String tenantId;
  final bool canManage;

  @override
  ConsumerState<_MercadoPagoSection> createState() => _MercadoPagoSectionState();
}

class _MercadoPagoSectionState extends ConsumerState<_MercadoPagoSection>
    with WidgetsBindingObserver {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(mercadoPagoConnectionProvider(widget.tenantId).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(mercadoPagoConnectionProvider(widget.tenantId));

    return connection.when(
      loading: () => const AppCard(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(child: CircularProgressIndicator()))),
      error: (error, _) => AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_message(error), style: AppTypography.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
            onPressed: () => ref
                .read(mercadoPagoConnectionProvider(widget.tenantId).notifier)
                .refresh(),
            child: const Text('Tentar novamente'))
      ])),
      data: (value) => _buildStatus(context, value),
    );
  }

  Widget _buildStatus(BuildContext context, MercadoPagoConnection connection) {
    final (label, color, icon) = switch (connection.status) {
      MercadoPagoConnectionStatus.connected => (
          'Conectado',
          AppColors.success,
          Icons.check_circle_rounded
        ),
      MercadoPagoConnectionStatus.expired => (
          'Conexão expirada',
          AppColors.warning,
          Icons.warning_amber_rounded
        ),
      MercadoPagoConnectionStatus.error => (
          'Erro na conexão',
          AppColors.error,
          Icons.error_rounded
        ),
      MercadoPagoConnectionStatus.disconnected => (
          'Conta não conectada',
          AppColors.muted,
          Icons.link_off_rounded
        ),
    };

    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(label,
                style: AppTypography.textTheme.titleMedium?.copyWith(color: color))),
      ]),
      if (connection.mpUserIdMasked != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text('Conta: ${connection.mpUserIdMasked}',
            style: AppTypography.textTheme.bodySmall),
      ],
      if (connection.connectedAt != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text('Conectado em: ${_formatDate(connection.connectedAt!)}',
            style: AppTypography.textTheme.bodySmall),
      ],
      if (widget.canManage) ...[
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          if (connection.status == MercadoPagoConnectionStatus.disconnected)
            AppButton(
                label: 'Conectar Mercado Pago',
                isLoading: _working,
                onPressed: _working ? null : _connect),
          if (connection.status == MercadoPagoConnectionStatus.expired ||
              connection.status == MercadoPagoConnectionStatus.error)
            AppButton(
                label: 'Reconectar Mercado Pago',
                isLoading: _working,
                onPressed: _working ? null : _connect),
          if (connection.status != MercadoPagoConnectionStatus.disconnected)
            TextButton(
                onPressed: _working ? null : _disconnect,
                child: const Text('Desconectar Mercado Pago')),
        ]),
      ],
    ]));
  }

  Future<void> _connect() async {
    setState(() => _working = true);
    try {
      await ref.read(mercadoPagoConnectionProvider(widget.tenantId).notifier).connect();
    } catch (error) {
      _snack(error is SettingsException
          ? error.message
          : 'Não foi possível conectar o Mercado Pago.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _working = true);
    try {
      await ref.read(mercadoPagoConnectionProvider(widget.tenantId).notifier).disconnect();
      _snack('Mercado Pago desconectado.');
    } catch (error) {
      _snack(error is SettingsException
          ? error.message
          : 'Não foi possível desconectar o Mercado Pago.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.settings});
  final TenantSettings settings;

  @override
  Widget build(BuildContext context) => AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dados da organização',
            style: AppTypography.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('Slug: ${settings.slug}', style: AppTypography.textTheme.bodySmall),
        Text('Status: ${_statusLabel(settings.status)}',
            style: AppTypography.textTheme.bodySmall),
        Text('Fuso horário: ${settings.timezone}',
            style: AppTypography.textTheme.bodySmall),
        Text('Moeda: ${settings.currency}',
            style: AppTypography.textTheme.bodySmall),
      ]));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            TextButton(
                onPressed: onRetry, child: const Text('Tentar novamente'))
          ])));
}