// Changelog:
// 2026-09-21: Marketplace 1:1 + Payment Brick (Prompt Mestre, item 7/8) —
// reescrita para o novo contrato das Edge Functions.
// - CheckoutResult ganhou mercadopagoPublicKey e grossAmount (ambos
//   devolvidos por create-public-order agora); removido paymentUrl — a
//   function nunca mais devolve isso (Checkout Pro foi descontinuado).
//   mercadopagoPublicKey pode vir null (tenant sem conexão Mercado Pago
//   conectada/ativa) — quem consome decide como tratar (ver
//   checkout_controller/checkout_page).
// - PaymentPreference removida (representava a resposta do extinto
//   createPreference/init_point). Substituída por duas classes que
//   espelham exatamente o contrato do Payment Brick:
//   - BrickPaymentSubmitData: o que o componente do Brick
//     (mercadopago_payment_brick.dart, a ser criado) recebe do SDK JS no
//     onSubmit e repassa ao repository — payment_method_id, token
//     (ausente em métodos como Pix), installments, issuer_id, payer.
//   - PaymentResult: o que create-payment devolve depois de criar o
//     pagamento (payment_id, status, status_detail, point_of_interaction —
//     este último com qr_code/qr_code_base64/ticket_url, usado por Pix;
//     ausente/null em cartão).
// - CheckoutRequest sem alteração de campos (continua sendo o payload de
//   create-public-order; catalog_products de 2026-09-20 preservado).

class CheckoutRequest {
  const CheckoutRequest({
    required this.campaignId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.products,
    this.catalogProducts = const <String, int>{},
    required this.idempotencyKey,
  });

  final String campaignId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final Map<String, int> products;
  final Map<String, int> catalogProducts;
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
        'campaign_id': campaignId,
        'customer_name': customerName.trim(),
        'customer_email': customerEmail.trim().toLowerCase(),
        'customer_phone': customerPhone.trim(),
        'products': products,
        'catalog_products': catalogProducts,
        'idempotency_key': idempotencyKey,
      };
}

class CheckoutResult {
  const CheckoutResult({
    required this.orderId,
    this.status = 'pending',
    this.grossAmount,
    this.mercadopagoPublicKey,
  });

  final String orderId;
  final String status;
  final num? grossAmount;

  /// null quando o tenant da campanha não tem conta Mercado Pago conectada
  /// (status != 'connected') — nesse caso o Payment Brick não pode ser
  /// inicializado.
  final String? mercadopagoPublicKey;

  factory CheckoutResult.fromMap(Map<String, dynamic> map) {
    return CheckoutResult(
      orderId: map['order_id'] as String? ?? map['id'] as String,
      status: map['status'] as String? ?? 'pending',
      grossAmount: map['gross_amount'] as num?,
      mercadopagoPublicKey: map['mercadopago_public_key'] as String?,
    );
  }
}

/// Dados que o SDK JS do Payment Brick devolve no callback onSubmit,
/// repassados ao backend sem alteração. token/issuerId vêm ausentes em
/// métodos sem tokenização de cartão (ex.: Pix).
class BrickPaymentSubmitData {
  const BrickPaymentSubmitData({
    required this.paymentMethodId,
    this.token,
    this.installments,
    this.issuerId,
    required this.payerEmail,
    this.payerIdentificationType,
    this.payerIdentificationNumber,
  });

  final String paymentMethodId;
  final String? token;
  final int? installments;
  final String? issuerId;
  final String payerEmail;
  final String? payerIdentificationType;
  final String? payerIdentificationNumber;

  Map<String, dynamic> toJson(String orderId) => {
        'order_id': orderId,
        'payment_method_id': paymentMethodId,
        if (token != null) 'token': token,
        if (installments != null) 'installments': installments,
        if (issuerId != null) 'issuer_id': issuerId,
        'payer': {
          'email': payerEmail,
          if (payerIdentificationType != null && payerIdentificationNumber != null)
            'identification': {
              'type': payerIdentificationType,
              'number': payerIdentificationNumber,
            },
        },
      };
}

/// point_of_interaction.transaction_data, usado por Pix (qr_code para
/// copia-e-cola, qr_code_base64 para exibir a imagem, ticket_url).
class PaymentPointOfInteraction {
  const PaymentPointOfInteraction({this.qrCode, this.qrCodeBase64, this.ticketUrl});

  final String? qrCode;
  final String? qrCodeBase64;
  final String? ticketUrl;

  factory PaymentPointOfInteraction.fromMap(Map<String, dynamic>? map) {
    final data = map?['transaction_data'] as Map<String, dynamic>?;
    return PaymentPointOfInteraction(
      qrCode: data?['qr_code'] as String?,
      qrCodeBase64: data?['qr_code_base64'] as String?,
      ticketUrl: data?['ticket_url'] as String?,
    );
  }
}

class PaymentResult {
  const PaymentResult({
    required this.paymentId,
    required this.status,
    required this.statusDetail,
    this.pointOfInteraction,
  });

  final int paymentId;
  final String status; // approved | pending | in_process | rejected | ...
  final String statusDetail;
  final PaymentPointOfInteraction? pointOfInteraction;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isAwaitingConfirmation => status == 'pending' || status == 'in_process';

  factory PaymentResult.fromMap(Map<String, dynamic> map) {
    final paymentId = map['payment_id'];
    if (paymentId is! num) {
      throw const FormatException('Resposta de pagamento sem payment_id.');
    }
    return PaymentResult(
      paymentId: paymentId.toInt(),
      status: map['status'] as String? ?? 'pending',
      statusDetail: map['status_detail'] as String? ?? '',
      pointOfInteraction: map['point_of_interaction'] == null
          ? null
          : PaymentPointOfInteraction.fromMap(
              map['point_of_interaction'] as Map<String, dynamic>),
    );
  }
}