// CHANGELOG
// 2026-09-19 — P6 / Trilha D (Contratos de grupo)
// - Corrigido o join usado em list/findById: `events(name)` foi adicionado
//   porque o domain agora deriva o título exibido do nome do evento (a
//   coluna `title` nunca existiu em group_contracts).
// - Implementadas as mutações que faltavam: create, edit, sign, pay, cancel.
//   Seguem o padrão descrito na seção 2 do prompt mestre (copiado da
//   descrição, não de catalog_repository.dart — o arquivo não foi
//   disponibilizado nesta trilha):
//     * filtro `.eq('tenant_id', tenantId)` em toda mutação;
//     * `.select('id')` no fim de UPDATE e checagem de vazio (RLS não gera
//       erro, apenas afeta 0 linhas — precisa virar erro explícito aqui);
//     * tradução de 23505/23503/23514/42501 para mensagem em português via
//       GroupContractsException.
// - As transições (sign/pay/cancel) usam `.eq('status', <status_esperado>)`
//   como guarda otimista: não existe trigger nem constraint de transição no
//   banco (confirmado em pg_constraint), então a corrida entre duas abas só é
//   evitada aqui. 0 linhas afetadas vira mensagem "o contrato já mudou de
//   status", não uma falha genérica.
// - edit() só é aceito com o contrato em 'draft' (`.eq('status', 'draft')`),
//   e não altera group_id/event_id — o formulário de edição não oferece
//   trocar grupo ou evento após a criação (identidade do contrato).
// - Adicionados listGroupOptions/listEventOptions: leitura simples de
//   `id, name` em `groups` e `events` para popular os seletores do formulário
//   de criação. Não é um repository novo nem uma tabela nova — mesma classe,
//   mesmas tabelas já usadas no join.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/group_contract.dart';

/// Opção simples para os seletores de grupo/evento do formulário.
typedef ContractOption = ({String id, String name});

class GroupContractsException implements Exception {
  const GroupContractsException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _selectWithRelations = '*, groups(name), events(name)';

final class GroupContractsRepository {
  GroupContractsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<GroupContract>> list({required String tenantId}) async {
    try {
      final rows = await _client
          .from('group_contracts')
          .select(_selectWithRelations)
          .eq('tenant_id', tenantId)
          .order('starts_at', ascending: false);
      return rows.map(GroupContract.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  Future<GroupContract> findById(
      {required String tenantId, required String id}) async {
    try {
      final row = await _client
          .from('group_contracts')
          .select(_selectWithRelations)
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .single();
      return GroupContract.fromMap(row);
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  Future<GroupContract> create({
    required String tenantId,
    required String groupId,
    required String eventId,
    required String feeAmount,
    required DateTime startsAt,
    DateTime? endsAt,
    String? terms,
    String currency = 'BRL',
  }) async {
    try {
      final row = await _client
          .from('group_contracts')
          .insert({
            'tenant_id': tenantId,
            'group_id': groupId,
            'event_id': eventId,
            'cache_amount': feeAmount,
            'currency': currency,
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt?.toUtc().toIso8601String(),
            'terms': terms,
          })
          .select(_selectWithRelations)
          .single();
      return GroupContract.fromMap(row);
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  /// Edita um contrato em rascunho. Grupo e evento não são alteráveis por
  /// aqui: mudar a identidade do contrato depois de criado não faz parte do
  /// escopo desta trilha.
  Future<void> edit({
    required String tenantId,
    required String id,
    required String feeAmount,
    required DateTime startsAt,
    DateTime? endsAt,
    String? terms,
  }) async {
    try {
      final result = await _client
          .from('group_contracts')
          .update({
            'cache_amount': feeAmount,
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt?.toUtc().toIso8601String(),
            'terms': terms,
          })
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .eq('status', 'draft')
          .select('id');
      if (result.isEmpty) {
        throw const GroupContractsException(
          'Só é possível editar contratos em rascunho. Atualize a lista e tente novamente.',
        );
      }
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  Future<void> sign({required String tenantId, required String id}) async {
    await _transition(
      tenantId: tenantId,
      id: id,
      expectedStatus: 'draft',
      update: {
        'status': 'signed',
        'signed_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictMessage:
          'Este contrato não está mais em rascunho. Atualize a lista e tente novamente.',
    );
  }

  Future<void> pay({required String tenantId, required String id}) async {
    await _transition(
      tenantId: tenantId,
      id: id,
      expectedStatus: 'signed',
      update: {
        'status': 'paid',
        'paid_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictMessage:
          'Este contrato não está mais assinado. Atualize a lista e tente novamente.',
    );
  }

  Future<void> cancel({required String tenantId, required String id}) async {
    try {
      final result = await _client
          .from('group_contracts')
          .update({'status': 'cancelled'})
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .inFilter('status', const ['draft', 'signed'])
          .select('id');
      if (result.isEmpty) {
        throw const GroupContractsException(
          'Este contrato já está pago ou cancelado e não pode mais ser alterado.',
        );
      }
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  Future<void> _transition({
    required String tenantId,
    required String id,
    required String expectedStatus,
    required Map<String, dynamic> update,
    required String conflictMessage,
  }) async {
    try {
      final result = await _client
          .from('group_contracts')
          .update(update)
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .eq('status', expectedStatus)
          .select('id');
      if (result.isEmpty) {
        throw GroupContractsException(conflictMessage);
      }
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  Future<List<ContractOption>> listGroupOptions(
      {required String tenantId}) async {
    try {
      final rows = await _client
          .from('groups')
          .select('id, name')
          .eq('tenant_id', tenantId)
          .order('name');
      return rows
          .map((row) => (id: row['id'] as String, name: row['name'] as String))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  Future<List<ContractOption>> listEventOptions(
      {required String tenantId}) async {
    try {
      final rows = await _client
          .from('events')
          .select('id, name')
          .eq('tenant_id', tenantId)
          .order('starts_at', ascending: false);
      return rows
          .map((row) => (id: row['id'] as String, name: row['name'] as String))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw GroupContractsException(_translate(error));
    }
  }

  String _translate(PostgrestException error) {
    switch (error.code) {
      case '23505':
        return 'Já existe um contrato conflitante para este grupo e evento.';
      case '23503':
        return 'Grupo ou evento inválido para este contrato.';
      case '23514':
        return 'Valor de cachê inválido: precisa ser maior ou igual a zero.';
      case '42501':
        return 'Você não tem permissão para gerenciar contratos desta organização. '
            'É necessário o perfil owner, admin ou finance.';
      default:
        final message = error.message.trim();
        return message.isEmpty
            ? 'Não foi possível concluir a operação no contrato.'
            : 'Não foi possível concluir a operação: $message';
    }
  }
}