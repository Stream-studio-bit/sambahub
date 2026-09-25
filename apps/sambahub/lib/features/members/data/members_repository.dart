// CHANGELOG
// 2026-09-19 — P7 / Trilha E (Membros)
// - updateRole/updateStatus passaram a seguir o padrão da seção 2 do prompt
//   mestre: .eq('tenant_id', tenantId) já existia, mas faltava .select('id')
//   com checagem de vazio. A policy memberships_manage (can_manage_tenant)
//   nega silenciosamente — a RLS não gera erro, apenas afeta 0 linhas — então
//   sem essa checagem uma tentativa negada parecia sucesso.
// - Adicionada MembersException traduzindo 42501 (usuário sem permissão de
//   gerenciar o tenant — a policy memberships_manage exige can_manage_tenant,
//   confirmado via pg_policy) e 23514 (valor de role/status fora do CHECK,
//   defensivo — a UI já restringe os valores, isso só cobre uma chamada
//   direta ao repository fora da tela).
// - Nenhuma proteção contra alterar/suspender o owner existe na RLS
//   (memberships_manage cobre qualquer role via can_manage_tenant, sem
//   exceção para a própria linha do owner). Essa proteção é feita no
//   controller, não aqui, porque o repository não tem acesso ao objeto
//   TenantMember completo — só ao id e ao valor novo.
// - list() ganhou o mesmo tratamento de erro, por consistência (a policy de
//   leitura é ampla — is_tenant_member —, então isso cobre principalmente o
//   caso de token expirado).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/tenant_member.dart';

class MembersException implements Exception {
  const MembersException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class MembersRepository {
  MembersRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<TenantMember>> list({required String tenantId}) async {
    try {
      final rows = await _client
          .from('tenant_memberships')
          .select('*, profiles(name, email)')
          .eq('tenant_id', tenantId)
          .order('created_at');
      return rows.map(TenantMember.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      throw MembersException(_translate(error));
    }
  }

  Future<void> updateRole({
    required String tenantId,
    required String membershipId,
    required String role,
  }) async {
    try {
      final result = await _client
          .from('tenant_memberships')
          .update({'role': role})
          .eq('id', membershipId)
          .eq('tenant_id', tenantId)
          .select('id');
      if (result.isEmpty) {
        throw const MembersException(
          'Não foi possível alterar a função deste membro. '
          'Você pode não ter mais permissão, ou o membro foi removido.',
        );
      }
    } on PostgrestException catch (error) {
      throw MembersException(_translate(error));
    }
  }

  Future<void> updateStatus({
    required String tenantId,
    required String membershipId,
    required String status,
  }) async {
    try {
      final result = await _client
          .from('tenant_memberships')
          .update({'status': status})
          .eq('id', membershipId)
          .eq('tenant_id', tenantId)
          .select('id');
      if (result.isEmpty) {
        throw const MembersException(
          'Não foi possível alterar o status deste membro. '
          'Você pode não ter mais permissão, ou o membro foi removido.',
        );
      }
    } on PostgrestException catch (error) {
      throw MembersException(_translate(error));
    }
  }

  String _translate(PostgrestException error) {
    switch (error.code) {
      case '42501':
        return 'Você não tem permissão para gerenciar membros desta organização.';
      case '23514':
        return 'Função ou status inválidos para este membro.';
      default:
        final message = error.message.trim();
        return message.isEmpty
            ? 'Não foi possível concluir a operação.'
            : 'Não foi possível concluir a operação: $message';
    }
  }
}