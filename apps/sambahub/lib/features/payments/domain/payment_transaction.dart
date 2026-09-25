class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.providerTransactionId,
    this.paymentFee = '0.00',
    this.providerStatus,
    this.paidAt,
    this.lastWebhookAt,
  });

  final String id;
  final String orderId;
  final String provider;
  final String status;
  final String amount;
  final String paymentFee;
  final String? providerTransactionId;
  final String? providerStatus;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? lastWebhookAt;

  bool get isApproved => status == 'approved';

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      provider: map['provider'] as String,
      status: map['status'] as String,
      amount: map['amount'].toString(),
      paymentFee: map['payment_fee']?.toString() ?? '0.00',
      providerTransactionId: map['provider_transaction_id'] as String?,
      providerStatus: map['provider_status'] as String?,
      createdAt: DateTime.parse(map['created_at'].toString()),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.tryParse(map['paid_at'].toString()),
      lastWebhookAt: map['last_webhook_at'] == null
          ? null
          : DateTime.tryParse(map['last_webhook_at'].toString()),
    );
  }
}
