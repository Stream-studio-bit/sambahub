// CHANGELOG
// 2026-09-21: Adicionados métodos de integração Mercado Pago (Prompt Mestre,
// item 12), chamando a Edge Function mp-marketplace-oauth já entregue
// (actions: connect, status, disconnect). Essa function usa um envelope
// próprio ({ok, ...} / {ok:false, error:{code,message}}), diferente do
// {data,error,meta} usado pelas demais Edge Functions do projeto — por isso
// o parsing é feito separadamente em _callMercadoPagoOAuth, sem reaproveitar
// _translate (que é específico de PostgrestException). O frontend nunca
// recebe access_token/refresh_token: a Edge Function garante isso, e
// MercadoPagoConnection.fromMap só sabe ler status/mp_user_id
// mascarado/connected_at.
// getMyRole/get/update/_translate mantidos sem alteração de lógica
// (changelog anterior, 2026-09-19, preservado abaixo).
//
// 2026-09-19: P11 (Trilha G) — ajustes no SettingsRepository.
// - update: antes usava .single(); se a RLS bloqueasse (0 linhas, sem erro)
//   estourava um erro cru do PostgREST. Agora usa .select() e lança
//   SettingsException se voltar vazio (sem permissão ou organização
//   inexistente). Mantém .eq('id', tenantId) (em tenants, id é o tenant).
// - get: usa maybeSingle e ignora deleted_at; lança SettingsException se a
//   organização não for encontrada/visível.
// - Tradução dos códigos Postgres 23505, 23503, 23514 e 42501 para mensagem em
//   português (SettingsException).
// - Novo: getMyRole(tenantId) lê o papel do usuário logado em
//   tenant_memberships (status 'active'), para a página liberar/bloquear a
//   edição. A RLS de UPDATE em tenants exige can_manage_tenant(id); o banco é a
//   autoridade, a UI só evita oferecer o que seria negado.
// - Colunas usadas (todas confirmadas no banco): name, legal_name, email,
//   phone, timezone, notifications_enabled, checkin_enabled. Assinaturas de
//   get/update não mudaram.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/mercadopago_connection.dart';
import '../domain/tenant_settings.dart';

/// Erro com mensagem pronta para exibir ao usuário.
final class SettingsException implements Exception {
  const SettingsException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class SettingsRepository {
  SettingsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<TenantSettings> get({required String tenantId}) async {
    try {
      final row = await _client
          .from('tenants')
          .select()
          .eq('id', tenantId)
          .isFilter('deleted_at', null)
          .maybeSingle();
      if (row == null) {
        throw const SettingsException(
            'Organização não encontrada ou sem acesso.');
      }
      return TenantSettings.fromMap(row);
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  Future<TenantSettings> update({
    required String tenantId,
    required String name,
    String? legalName,
    String? email,
    String? phone,
    String? timezone,
    bool? notificationsEnabled,
    bool? checkinEnabled,
  }) async {
    final values = <String, dynamic>{
      'name': name.trim(),
      'legal_name': _nullable(legalName),
      'email': _nullable(email),
      'phone': _nullable(phone),
      if (timezone != null) 'timezone': timezone,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (checkinEnabled != null) 'checkin_enabled': checkinEnabled,
    };
    try {
      final rows = await _client
          .from('tenants')
          .update(values)
          .eq('id', tenantId)
          .select();
      if (rows.isEmpty) {
        throw const SettingsException(
            'Não foi possível salvar: você não tem permissão para alterar esta organização.');
      }
      return TenantSettings.fromMap(rows.first);
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  /// Papel do usuário logado nesta organização (membership ativo) ou null.
  Future<String?> getMyRole({required String tenantId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('tenant_memberships')
          .select('role')
          .eq('tenant_id', tenantId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      return row?['role'] as String?;
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  /// Estado atual da conexão Mercado Pago do tenant (nunca contém tokens —
  /// mp-marketplace-oauth/action=status já devolve mp_user_id mascarado).
  /// A própria Edge Function renova o token perto de expirar antes de
  /// responder, então "expired" aqui reflete de fato a necessidade de um
  /// novo OAuth completo, não só um refresh pendente.
  Future<MercadoPagoConnection> getMercadoPagoStatus({
    required String tenantId,
  }) {
    return _invokeMercadoPagoAction(action: 'status', tenantId: tenantId);
  }

  /// Inicia (ou reinicia) o fluxo OAuth e devolve a authorization_url que o
  /// Flutter deve abrir no navegador (url_launcher). Usado tanto pelo botão
  /// "Conectar Mercado Pago" quanto por "Reconectar Mercado Pago" — é o
  /// mesmo fluxo completo de OAuth nos dois casos.
  Future<String> connectMercadoPago({required String tenantId}) async {
    final body = await _callMercadoPagoOAuth(action: 'connect', tenantId: tenantId);
    final url = body['authorization_url'] as String?;
    if (url == null || url.isEmpty) {
      throw const SettingsException(
          'Não foi possível iniciar a conexão com o Mercado Pago.');
    }
    return url;
  }

  Future<MercadoPagoConnection> disconnectMercadoPago({
    required String tenantId,
  }) {
    return _invokeMercadoPagoAction(action: 'disconnect', tenantId: tenantId);
  }

  Future<MercadoPagoConnection> _invokeMercadoPagoAction({
    required String action,
    required String tenantId,
  }) async {
    final body = await _callMercadoPagoOAuth(action: action, tenantId: tenantId);
    return MercadoPagoConnection.fromMap(body);
  }

  /// mp-marketplace-oauth responde com um envelope próprio
  /// ({ok:true,...} / {ok:false,error:{code,message}}), diferente do
  /// {data,error,meta} das demais Edge Functions — por isso o parsing fica
  /// isolado aqui em vez de reaproveitar _translate.
  Future<Map<String, dynamic>> _callMercadoPagoOAuth({
    required String action,
    required String tenantId,
  }) async {
    Map<String, dynamic>? body;
    try {
      final response = await _client.functions.invoke(
        'mp-marketplace-oauth',
        body: {'action': action, 'tenant_id': tenantId},
      );
      final data = response.data;
      if (data is Map) body = Map<String, dynamic>.from(data);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map) body = Map<String, dynamic>.from(details);
    }

    if (body == null) {
      throw const SettingsException(
          'Falha na comunicação com o Mercado Pago.');
    }
    if (body['ok'] != true) {
      final error = body['error'];
      final message = error is Map ? error['message'] as String? : null;
      throw SettingsException(message ?? 'Falha na comunicação com o Mercado Pago.');
    }
    return body;
  }

  SettingsException _translate(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return const SettingsException(
            'Já existe uma organização com estes dados.');
      case '23503':
        return const SettingsException(
            'Este registro está vinculado a outros dados e não pode ser alterado.');
      case '23514':
        return const SettingsException(
            'Valor inválido em algum campo. Confira os dados e tente de novo.');
      case '42501':
        return const SettingsException(
            'Você não tem permissão para alterar estas configurações.');
      default:
        return SettingsException(e.message);
    }
  }

  String? _nullable(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}