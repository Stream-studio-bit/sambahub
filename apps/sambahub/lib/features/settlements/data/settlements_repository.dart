// CHANGELOG
// 2026-09-19 — P8 / Trilha C (Repasses)
// - Adicionada SettlementsException traduzindo 42501. A policy
//   settlements_finance_all cobre leitura E escrita com can_manage_finance
//   (diferente de group_contracts, onde a leitura era aberta a qualquer
//   membro) — então um usuário sem o perfil owner/admin/finance pode não ver
//   nenhum repasse (RLS filtra silenciosamente, sem erro) ou, se a função
//   can_manage_finance falhar por outro motivo, receber 42501 explícito.
//   Os dois casos agora têm mensagem em português em vez de tela genérica.
// - list()/findById() não tinham nenhum tratamento de erro antes; a página
//   já tinha um _ErrorState, mas sem mensagem específica.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/settlement.dart';

class SettlementsException implements Exception {
  const SettlementsException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class SettlementsRepository {
  SettlementsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<Settlement>> list({required String tenantId}) async {
    try {
      final rows = await _client
          .from('settlements')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);
      return rows.map(Settlement.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      throw SettlementsException(_translate(error));
    }
  }

  Future<Settlement> findById(
      {required String tenantId, required String id}) async {
    try {
      final row = await _client
          .from('settlements')
          .select()
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .single();
      return Settlement.fromMap(row);
    } on PostgrestException catch (error) {
      throw SettlementsException(_translate(error));
    }
  }

  String _translate(PostgrestException error) {
    if (error.code == '42501') {
      return 'Você não tem permissão para ver os repasses desta organização. '
          'É necessário o perfil owner, admin ou finance.';
    }
    final message = error.message.trim();
    return message.isEmpty
        ? 'Não foi possível carregar os repasses.'
        : 'Não foi possível carregar os repasses: $message';
  }
}