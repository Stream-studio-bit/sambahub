// CHANGELOG
// 2026-09-19 — P5 / Trilha C (Relatórios)
// - Criada ReportsException (mesma ideia de CatalogException): mensagem pronta
//   em português para a página exibir, em vez de PostgrestException crua.
//   Traduz 42501 (RLS/can_manage_finance), PGRST202 e 42883 (RPC ausente ou
//   assinatura diferente), 22P02 (parâmetro inválido) e 57014 (timeout).
// - Parsing da resposta da RPC aceita Map e List. A assinatura confirmada em
//   pg_proc é (p_tenant_id uuid, p_period_start timestamptz, p_period_end
//   timestamptz), mas o corpo pode ser RETURNS TABLE, que chega como lista de
//   uma linha; a versão anterior lançava FormatException nesse caso.
// - Validação de entrada antes do RPC: tenantId vazio (acontece quando a rota
//   é aberta sem ?tenant=<id>) e período invertido viram mensagem clara em vez
//   de erro 400 do PostgREST.
// - Nomes dos parâmetros e da função mantidos. Nenhuma coluna ou RPC nova.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/report_summary.dart';

/// Erro de relatório já traduzido para exibição direta na página.
class ReportsException implements Exception {
  const ReportsException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ReportsRepository {
  ReportsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<ReportSummary> summary({
    required String tenantId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw const ReportsException(
        'Organização não identificada. Abra os relatórios a partir da lista de organizações.',
      );
    }
    if (!periodEnd.isAfter(periodStart)) {
      throw const ReportsException(
        'O fim do período precisa ser depois do início.',
      );
    }

    Object? response;
    try {
      response = await _client.rpc(
        'get_tenant_report_summary',
        params: {
          'p_tenant_id': tenantId,
          'p_period_start': periodStart.toUtc().toIso8601String(),
          'p_period_end': periodEnd.toUtc().toIso8601String(),
        },
      );
    } on PostgrestException catch (error) {
      throw ReportsException(_translate(error));
    } on AuthException {
      throw const ReportsException(
        'Sua sessão expirou. Entre novamente para ver os relatórios.',
      );
    } catch (_) {
      throw const ReportsException(
        'Não foi possível carregar o relatório. Verifique sua conexão e tente novamente.',
      );
    }

    final row = _firstRow(response);
    if (row == null) {
      throw const ReportsException(
        'O relatório não retornou dados para este período.',
      );
    }

    try {
      return ReportSummary.fromMap({
        ...row,
        'period_start': row['period_start'] ?? periodStart.toIso8601String(),
        'period_end': row['period_end'] ?? periodEnd.toIso8601String(),
      });
    } catch (_) {
      throw const ReportsException(
        'Resposta inválida do relatório. Avise o suporte se o erro continuar.',
      );
    }
  }

  /// A RPC pode devolver um objeto (RETURNS json/record) ou uma lista de uma
  /// linha (RETURNS TABLE / SETOF). Os dois formatos são aceitos.
  Map<String, dynamic>? _firstRow(Object? response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return response.map((key, value) => MapEntry(key.toString(), value));
    }
    if (response is List && response.isNotEmpty) {
      return _firstRow(response.first as Object?);
    }
    return null;
  }

  String _translate(PostgrestException error) {
    switch (error.code) {
      case '42501':
        return 'Você não tem permissão para ver os relatórios desta organização. '
            'É necessário o perfil owner, admin ou finance.';
      case 'PGRST202':
      case '42883':
        return 'A função de relatório não está disponível no servidor. Avise o suporte.';
      case '22P02':
        return 'Período ou organização inválidos para a consulta.';
      case '57014':
        return 'A consulta demorou demais. Tente um período menor.';
      default:
        final message = error.message.trim();
        if (message.isEmpty) {
          return 'Não foi possível carregar o relatório.';
        }
        return 'Não foi possível carregar o relatório: $message';
    }
  }
}