// checkin_repository.dart
//
// CHANGELOG
// 2026-09-25 — Item 8 (Check-in), Handoff 08:
//   - Adicionado redeemCatalogItem(), espelhando validateTicket() mas
//     apontando para a Edge Function redeem-catalog-item (já criada e
//     aprovada nesta sessão anterior). Mesmo tratamento de FunctionException
//     via try/catch (evidência: mesma versão do pacote functions_client
//     usada por validateTicket, 2.7.1, lança FunctionsHttpException em
//     qualquer resposta não-2xx).
//   - Envelope de sucesso confirmado no código-fonte de redeem-catalog-item:
//     {data:{accepted, reason?, remaining_balance?, product_name?,
//     quantity_redeemed_now?, status?}}. Recusa (accepted=false) vira
//     Exception com mensagem traduzida por _catalogReasonMessage(), incluindo
//     o saldo restante na mensagem quando o servidor o devolve (reason
//     insufficient_balance sempre devolve remaining_balance, confirmado no
//     código-fonte).
//   - _reasonMessage() (ingresso) ganhou o caso 'event_ended', citado no
//     Handoff 08 como novo motivo de recusa que validate-ticket passará a
//     devolver (item 5, ainda não entregue nesta sequência, mas o contrato
//     já está especificado no handoff). Nenhuma outra lógica de
//     validateTicket() foi alterada.
//
// 2026-09-19 — Trilha A, P3 (depende do P1/validate-ticket e do P3b/webhook)
//   - validateTicket() agora envolve o _client.functions.invoke() em
//     try/catch para FunctionException. Evidência: functions_client 2.7.1
//     (pubspec.lock) lança FunctionsHttpException (subtipo de
//     FunctionException) em qualquer resposta não-2xx — o bloco antigo
//     `if (raw['error'] != null)` nunca era alcançado nesses casos (401 de
//     assinatura/permissão, 400 de entrada inválida, 500 interno do P1),
//     e a mensagem chegava ao controller como erro técnico do pacote, sem
//     tradução em português.
//   - Erro tratado (details é o envelope {data,error,meta} decodificado):
//     extrai details['error']['message'] quando existir; senão cai numa
//     mensagem genérica. Erro de rede/função inacessível (FunctionException
//     sem details utilizável, ou qualquer outra exceção) cai numa mensagem
//     genérica separada.
//   - Nenhuma mudança na lógica de negócio: parsing do envelope de sucesso
//     {data:{accepted,reason,ticket}}, accepted=false -> _reasonMessage(),
//     e eventName() ficam como estavam (item 8, 2026-09-18).
//
// 2026-09-18: Item 8 (Check-in) — adicionado eventName(eventId), consultando
// a tabela events (já existente, sem novo campo). Necessário porque
// checkin_page.dart não exibia o nome do evento, só titular e horário.
// Nenhuma lógica de validação foi tocada; validate-ticket continua sendo a
// única fonte de verdade para aceitar/recusar ingresso.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

final class CheckinRepository {
  CheckinRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> validateTicket({
    required String code,
    required String eventId,
    required String tenantId,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'validate-ticket',
        body: {
          'code': code.trim(),
          'event_id': eventId,
          'tenant_id': tenantId,
        },
      );
    } on FunctionException catch (e) {
      throw Exception(_functionExceptionMessage(e));
    }

    final raw = response.data;
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida da validação.');
    }
    if (raw['error'] != null) {
      // Mantido por segurança: caso alguma versão futura do client volte a
      // entregar erro tratado como resposta 2xx em vez de lançar exceção.
      final error = raw['error'];
      throw Exception(error is Map ? error['message'] ?? 'Ingresso recusado.' : error.toString());
    }

    final payload = raw['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>)
        : Map<String, dynamic>.from(raw);
    final ticket = payload['ticket'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['ticket'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final accepted = payload['accepted'] as bool? ?? false;
    if (!accepted) {
      throw Exception(_reasonMessage(payload['reason']?.toString()));
    }
    return {
      ...payload,
      'ticket_id': payload['ticket_id'] ?? ticket['id'],
      'ticket_code': payload['ticket_code'] ?? ticket['code'] ?? code,
      'holder_name': payload['holder_name'] ?? ticket['holder_name'],
      'checked_in_at': payload['checked_in_at'] ?? ticket['used_at'],
      'event_id': payload['event_id'] ?? eventId,
      'accepted': true,
      'message': 'Ingresso validado. Entrada liberada.',
    };
  }

  Future<Map<String, dynamic>> redeemCatalogItem({
    required String code,
    required String eventId,
    required String tenantId,
    int quantity = 1,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'redeem-catalog-item',
        body: {
          'code': code.trim(),
          'event_id': eventId,
          'tenant_id': tenantId,
          'quantity': quantity,
        },
      );
    } on FunctionException catch (e) {
      throw Exception(_functionExceptionMessage(e));
    }

    final raw = response.data;
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida da retirada.');
    }
    if (raw['error'] != null) {
      final error = raw['error'];
      throw Exception(error is Map ? error['message'] ?? 'Retirada recusada.' : error.toString());
    }

    final payload = raw['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>)
        : Map<String, dynamic>.from(raw);
    final accepted = payload['accepted'] as bool? ?? false;
    if (!accepted) {
      final remainingBalance = (payload['remaining_balance'] as num?)?.toInt();
      throw Exception(_catalogReasonMessage(payload['reason']?.toString(), remainingBalance));
    }
    return {
      ...payload,
      'accepted': true,
      'event_id': eventId,
      'message': _catalogSuccessMessage(payload),
    };
  }

  String _functionExceptionMessage(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final error = details['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    if (e.status == 401 || e.status == 403) {
      return 'Você não tem permissão para validar ingressos nesta organização.';
    }
    return 'Falha ao validar ingresso (erro ${e.status}). Tente novamente.';
  }

  String _reasonMessage(String? reason) => switch (reason) {
        'ticket_not_found' => 'Ingresso não encontrado para este evento.',
        'ticket_used' || 'already_used' => 'Este ingresso já foi utilizado.',
        'ticket_cancelled' => 'Este ingresso foi cancelado.',
        'ticket_refunded' => 'Este ingresso foi reembolsado.',
        'tenant_mismatch' => 'Ingresso não pertence a esta organização.',
        'event_ended' => 'Este evento já foi encerrado.',
        _ => 'Ingresso recusado. Verifique o código e tente novamente.',
      };

  String _catalogReasonMessage(String? reason, int? remainingBalance) => switch (reason) {
        'redemption_not_found' => 'Código de retirada não encontrado para este evento.',
        'tenant_mismatch' => 'Retirada não pertence a esta organização.',
        'event_mismatch' => 'Retirada não pertence a este evento.',
        'redemption_cancelled' => 'Esta retirada foi cancelada.',
        'redemption_expired' => 'Prazo de retirada expirado (15 dias após o pagamento).',
        'redemption_completed' => 'Todos os itens deste código já foram retirados.',
        'insufficient_balance' => remainingBalance != null
            ? 'Saldo insuficiente. Restam $remainingBalance unidade(s) para retirar.'
            : 'Saldo insuficiente para a quantidade informada.',
        'concurrent_update' => 'Outra leitura simultânea alterou este código. Tente novamente.',
        _ => 'Retirada recusada. Verifique o código e tente novamente.',
      };

  String _catalogSuccessMessage(Map<String, dynamic> payload) {
    final name = payload['product_name']?.toString() ?? 'produto';
    final qty = payload['quantity_redeemed_now'];
    final remaining = payload['remaining_balance'];
    return 'Retirada de $name confirmada ($qty un.). Saldo restante: $remaining.';
  }

  Future<String?> eventName(String eventId) async {
    final row = await _client
        .from('events')
        .select('name')
        .eq('id', eventId)
        .maybeSingle();
    return row?['name'] as String?;
  }
}