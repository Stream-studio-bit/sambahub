// Changelog:
// 2026-09-21: Marketplace 1:1 + Payment Brick (Prompt Mestre, item 7) —
// createPayment agora recebe BrickPaymentSubmitData (dados que o
// mercadopago_payment_brick.dart vai coletar do SDK JS) em vez de só
// orderId, e devolve PaymentResult (payment_id/status/status_detail/
// point_of_interaction) em vez de PaymentPreference (init_point do extinto
// Checkout Pro — não existe mais). create-payment deixou de ser idempotente
// no sentido de "repetir devolve o mesmo link": cada chamada agora tenta
// criar um pagamento de fato (o SDK do Brick já gera um token novo por
// tentativa); a idempotência de create-payment continua garantida no
// backend via idempotency_key do pedido (Prompt Mestre, item 6), não por
// este repository.
// createOrder mantido sem alteração de lógica — só passou a devolver
// CheckoutResult com mercadopagoPublicKey/grossAmount (CheckoutResult.fromMap
// já contempla isso).
//
// 2026-09-19: P9 (Trilha F) — adicionado createPayment(orderId), que chama a
// Edge Function create-payment e devolve PaymentPreference (payment_url,
// preference_id). Motivo: create-public-order sempre devolve payment_url: null
// por design; sem esta chamada o cliente nunca chega ao Mercado Pago.
// Respostas não-2xx da function (409 pedido não pagável/já pago, 404, 500, 502)
// chegam como FunctionException; a mensagem do envelope { error: { message } }
// é extraída e propagada. createOrder não foi alterado.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/checkout_request.dart';

final class CheckoutRepository {
  CheckoutRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<CheckoutResult> createOrder(CheckoutRequest request) async {
    final response = await _client.functions.invoke(
      'create-public-order',
      body: request.toJson(),
    );

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida do checkout.');
    }

    final error = payload['error'];
    if (error != null) {
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : error.toString();
      throw Exception(message ?? 'Não foi possível criar o pedido.');
    }

    final data = payload['data'];
    final result = data is Map<String, dynamic> ? data : payload;
    return CheckoutResult.fromMap(result);
  }

  /// Envia ao backend os dados que o Payment Brick coletou (token/
  /// payment_method_id/etc.) e cria o pagamento de fato. Cada chamada tenta
  /// criar um pagamento novo — a idempotência fica a cargo do backend
  /// (idempotency_key do pedido), não deste método.
  Future<PaymentResult> createPayment(
    String orderId,
    BrickPaymentSubmitData submitData,
  ) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'create-payment',
        body: submitData.toJson(orderId),
      );
    } on FunctionException catch (e) {
      throw Exception(
        _errorMessage(e.details) ?? 'Não foi possível processar o pagamento.',
      );
    }

    final payload = response.data;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida do pagamento.');
    }

    final message = _errorMessage(payload);
    if (message != null) throw Exception(message);

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Resposta de pagamento sem dados.');
    }
    return PaymentResult.fromMap(data);
  }

  /// Extrai error.message do envelope { data, error, meta }.
  String? _errorMessage(Object? body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error == null) return null;
    if (error is Map) return error['message']?.toString();
    return error.toString();
  }
}