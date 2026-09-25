// CHANGELOG
// 2026-09-21 (fix pós flutter analyze): faltava um caractere "menor que" no
// final da primeira linha da declaração de mercadoPagoConnectionProvider
// (AsyncNotifierProviderFamily sem abrir os generics) — derrubava o parser
// a partir dali e vazava como dezenas de erros de tipo em cascata neste
// arquivo e em settings_page.dart (String "não é tipo", MercadoPagoConnection
// "definido duas vezes", ambiguous_import). Confirmado via `cat -A` que o
// caractere estava mesmo ausente no arquivo salvo — corrigido abaixo. Resto
// do arquivo sem alteração de lógica.
//
// 2026-09-21: Adicionado controller da conexão Mercado Pago (Prompt Mestre,
// item 12): mercadoPagoConnectionProvider (FamilyAsyncNotifier, não
// FutureProvider simples) — como AsyncNotifier, connect()/disconnect()
// atualizam o state diretamente com o que a Edge Function devolveu, sem
// passar por AsyncLoading (mesma lição do fix de save() abaixo: evita
// remontar a seção e perder feedback). connect() abre authorization_url via
// url_launcher (dependência já confirmada em pubspec.yaml) em
// LaunchMode.externalApplication — o OAuth roda no navegador, fora do app;
// refresh() fica disponível para a página chamar quando o app volta ao
// primeiro plano (didChangeAppLifecycleState), para refletir o resultado do
// callback. Permissão: mesma regra de save() (owner/admin via
// settingsRoleProvider) — reaproveitada, não duplicada.
//
// 2026-09-19: P11 (Trilha G) — ajustes no SettingsController.
// - save(): não troca mais o state por AsyncLoading (isso desmontava o
//   formulário e apagava o que o usuário digitou; a falha virava tela de
//   erro). Agora propaga SettingsException para a página e, no sucesso,
//   troca o state pelos dados devolvidos pelo banco (a atualização aparece na
//   hora).
// - Validação antes de chamar o repository, com SettingsValidation (nome,
//   e-mail, telefone, fuso horário).
// - Permissão: só owner/admin salvam (a RLS de UPDATE em tenants exige
//   can_manage_tenant = owner/admin, confirmado no banco). Bloqueia antes de
//   chamar o repository.
// - Novo: settingsRoleProvider(tenantId) com o papel do usuário logado, usado
//   pela página para liberar/bloquear a edição.
// - refresh() continua usando AsyncLoading (recarga completa) e também
//   invalida o papel.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/settings_repository.dart';
import '../domain/mercadopago_connection.dart';
import '../domain/settings_permissions.dart';
import '../domain/settings_validation.dart';
import '../domain/tenant_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

/// Papel do usuário logado na organização (null = sem vínculo ativo).
final settingsRoleProvider = FutureProvider.family<String?, String>(
  (ref, tenantId) =>
      ref.read(settingsRepositoryProvider).getMyRole(tenantId: tenantId),
);

final settingsControllerProvider =
    AsyncNotifierProviderFamily<SettingsController, TenantSettings, String>(
  SettingsController.new,
);

class SettingsController extends FamilyAsyncNotifier<TenantSettings, String> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  Future<TenantSettings> build(String tenantId) {
    return _repository.get(tenantId: tenantId);
  }

  Future<void> refresh() async {
    ref.invalidate(settingsRoleProvider(arg));
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.get(tenantId: arg));
  }

  /// Salva as configurações. Lança [SettingsException] em caso de validação,
  /// permissão ou falha do banco (o state atual é preservado nesses casos).
  Future<void> save({
    required String name,
    String? legalName,
    String? email,
    String? phone,
    String? timezone,
    bool? notificationsEnabled,
    bool? checkinEnabled,
  }) async {
    final validationError = SettingsValidation.name(name) ??
        SettingsValidation.email(email) ??
        SettingsValidation.phone(phone) ??
        (timezone == null ? null : SettingsValidation.timezone(timezone));
    if (validationError != null) throw SettingsException(validationError);

    final role = await ref.read(settingsRoleProvider(arg).future);
    if (role == null ||
        !SettingsPermissions.can(role, SettingsPermission.editOrganization)) {
      throw const SettingsException(
          'Apenas proprietários e administradores podem alterar as configurações.');
    }

    final updated = await _repository.update(
      tenantId: arg,
      name: name,
      legalName: legalName,
      email: email,
      phone: phone,
      timezone: timezone,
      notificationsEnabled: notificationsEnabled,
      checkinEnabled: checkinEnabled,
    );
    state = AsyncData(updated);
  }
}

final mercadoPagoConnectionProvider =
    AsyncNotifierProviderFamily<MercadoPagoConnectionController,
        MercadoPagoConnection, String>(
  MercadoPagoConnectionController.new,
);

class MercadoPagoConnectionController
    extends FamilyAsyncNotifier<MercadoPagoConnection, String> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  Future<MercadoPagoConnection> build(String tenantId) {
    return _repository.getMercadoPagoStatus(tenantId: tenantId);
  }

  /// Recarrega o status — usado após o app voltar do navegador (callback do
  /// OAuth roda fora do app) e pelo botão de tentar novamente.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getMercadoPagoStatus(tenantId: arg));
  }

  Future<void> _assertCanManage() async {
    final role = await ref.read(settingsRoleProvider(arg).future);
    if (role == null ||
        !SettingsPermissions.can(role, SettingsPermission.editOrganization)) {
      throw const SettingsException(
          'Apenas proprietários e administradores podem gerenciar o Mercado Pago.');
    }
  }

  /// Usado tanto por "Conectar Mercado Pago" quanto por "Reconectar Mercado
  /// Pago" — os dois disparam o mesmo fluxo OAuth completo. Abre a URL no
  /// navegador e retorna; o state só reflete a conexão depois de refresh()
  /// (chamado pela página quando o app volta ao primeiro plano).
  Future<void> connect() async {
    await _assertCanManage();
    final url = await _repository.connectMercadoPago(tenantId: arg);
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw const SettingsException(
          'Não foi possível abrir o navegador para conectar o Mercado Pago.');
    }
  }

  Future<void> disconnect() async {
    await _assertCanManage();
    final updated = await _repository.disconnectMercadoPago(tenantId: arg);
    state = AsyncData(updated);
  }
}