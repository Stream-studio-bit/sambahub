// lib/features/checkout/domain/checkout_controller.dart
//
// CHANGELOG
// 2026-09-22: Unificação de carrinho (campanha + catálogo).
// - submit() ganhou o parâmetro `catalogProducts: Map<String, int>`
//   (default `{}`), repassado para CheckoutRequest junto com `products`
//   (campanha). CheckoutRequest já expõe esse campo — não alterado aqui,
//   conforme escopo do plano. Nenhuma outra lógica de submit() mudou:
//   segue criando o pedido, checando mercadopagoPublicKey, etc.
// - submitPayment(), currentOrder, reset() e o restante do arquivo
//   permanecem exatamente como estavam — fora do escopo desta mudança.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/checkout_repository.dart';
import '../domain/checkout_request.dart';

final checkoutRepositoryProvider = Provider<CheckoutRepository>(
  (ref) => CheckoutRepository(),
);

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, AsyncValue<CheckoutFlowState?>>(
  CheckoutController.new,
);

/// Estado do fluxo: o pedido sempre presente uma vez criado; payment só
/// depois de uma tentativa bem-sucedida via submitPayment().
class CheckoutFlowState {
  const CheckoutFlowState({required this.order, this.payment});

  final CheckoutResult order;
  final PaymentResult? payment;

  CheckoutFlowState copyWith({PaymentResult? payment}) =>
      CheckoutFlowState(order: order, payment: payment ?? this.payment);
}

/// O pedido já existe (orderId sempre disponível), mas a tentativa de
/// pagamento falhou ou não pôde nem começar (ex.: sem public_key).
class CheckoutPaymentException implements Exception {
  const CheckoutPaymentException({required this.orderId, required this.cause});

  final String orderId;
  final Object cause;

  String get message => cause
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('FormatException: ', '');

  @override
  String toString() => 'CheckoutPaymentException($orderId): $message';
}

class CheckoutController extends Notifier<AsyncValue<CheckoutFlowState?>> {
  static const _uuid = Uuid();

  CheckoutRepository get _repository => ref.read(checkoutRepositoryProvider);

  @override
  AsyncValue<CheckoutFlowState?> build() => const AsyncData(null);

  /// Cria o pedido e para nesse estado — a página usa
  /// order.mercadopagoPublicKey pra inicializar o Brick e aguarda o usuário
  /// preencher o formulário de pagamento (submitPayment).
  Future<void> submit({
    required String campaignId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required Map<String, int> products,
    Map<String, int> catalogProducts = const {},
  }) async {
    state = const AsyncLoading();
    final request = CheckoutRequest(
      campaignId: campaignId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      products: products,
      catalogProducts: catalogProducts,
      idempotencyKey: _uuid.v4(),
    );

    final CheckoutResult order;
    try {
      order = await _repository.createOrder(request);
    } catch (e, st) {
      state = AsyncError(e, st);
      return;
    }

    if (order.mercadopagoPublicKey == null) {
      state = AsyncError(
        CheckoutPaymentException(
          orderId: order.orderId,
          cause: Exception(
            'Pagamento indisponível para esta campanha no momento.',
          ),
        ),
        StackTrace.current,
      );
      return;
    }

    state = AsyncData(CheckoutFlowState(order: order));
  }

  /// Chamado pela página quando o Payment Brick devolve os dados da
  /// tentativa de pagamento (onSubmit). Usa o pedido já criado — nunca cria
  /// outro. Em caso de falha, preserva o pedido no state anterior (lido de
  /// [currentOrder]) para a página poder renderizar o Brick de novo.
  Future<void> submitPayment(BrickPaymentSubmitData data) async {
    final order = currentOrder;
    if (order == null) {
      throw StateError('submitPayment chamado sem um pedido criado.');
    }

    state = AsyncData(CheckoutFlowState(order: order));
    try {
      final payment = await _repository.createPayment(order.orderId, data);
      state = AsyncData(CheckoutFlowState(order: order, payment: payment));
    } catch (e, st) {
      state = AsyncError(
        CheckoutPaymentException(orderId: order.orderId, cause: e),
        st,
      );
    }
  }

  /// Pedido do state atual, mesmo que o último passo tenha terminado em
  /// AsyncError (CheckoutPaymentException carrega só o orderId, não o
  /// CheckoutResult inteiro — a página precisa do pedido completo, com
  /// mercadopagoPublicKey, pra tentar o Brick de novo).
  CheckoutResult? get currentOrder => state.valueOrNull?.order;

  void reset() => state = const AsyncData(null);
}