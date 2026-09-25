// Changelog:
// 2026-09-18: Item 10 (Orders) — adicionado OrderTransactionSummary e campo
// transactions em SambaOrder, populados a partir do join payment_transactions
// (id, provider, status, amount, paid_at, refunded_at — todos campos já
// existentes na tabela). Necessário para exibir a "transação vinculada ao
// pedido" exigida pelo item 10.

class OrderItemSummary {
  const OrderItemSummary({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String id;
  final String productName;
  final int quantity;
  final String unitPrice;
  final String totalPrice;

  factory OrderItemSummary.fromMap(Map<String, dynamic> map) {
    return OrderItemSummary(
      id: map['id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      unitPrice: map['unit_price'].toString(),
      totalPrice: map['total_price'].toString(),
    );
  }
}

class OrderTransactionSummary {
  const OrderTransactionSummary({
    required this.id,
    required this.provider,
    required this.status,
    required this.amount,
    this.paidAt,
    this.refundedAt,
  });

  final String id;
  final String provider;
  final String status;
  final String amount;
  final DateTime? paidAt;
  final DateTime? refundedAt;

  factory OrderTransactionSummary.fromMap(Map<String, dynamic> map) {
    return OrderTransactionSummary(
      id: map['id'] as String,
      provider: map['provider'] as String,
      status: map['status'] as String,
      amount: map['amount'].toString(),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.tryParse(map['paid_at'].toString()),
      refundedAt: map['refunded_at'] == null
          ? null
          : DateTime.tryParse(map['refunded_at'].toString()),
    );
  }
}

class SambaOrder {
  const SambaOrder({
    required this.id,
    required this.campaignId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.status,
    required this.grossAmount,
    required this.createdAt,
    this.paidAt,
    this.items = const [],
    this.transactions = const [],
  });

  final String id;
  final String campaignId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String status;
  final String grossAmount;
  final DateTime createdAt;
  final DateTime? paidAt;
  final List<OrderItemSummary> items;
  final List<OrderTransactionSummary> transactions;

  bool get isPaid => status == 'paid';

  factory SambaOrder.fromMap(Map<String, dynamic> map) {
    final rawItems = map['order_items'] as List<dynamic>? ?? const [];
    final rawTransactions =
        map['payment_transactions'] as List<dynamic>? ?? const [];
    return SambaOrder(
      id: map['id'] as String,
      campaignId: map['campaign_id'] as String,
      customerName: map['customer_name'] as String,
      customerEmail: map['customer_email'] as String,
      customerPhone: map['customer_phone'] as String,
      status: map['status'] as String,
      grossAmount: map['gross_amount'].toString(),
      createdAt: DateTime.parse(map['created_at'].toString()),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.tryParse(map['paid_at'].toString()),
      items: rawItems
          .map((item) =>
              OrderItemSummary.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      transactions: rawTransactions
          .map((item) => OrderTransactionSummary.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
  }
}