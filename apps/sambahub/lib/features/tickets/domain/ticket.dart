class SambaTicket {
  const SambaTicket({
    required this.id,
    required this.orderId,
    required this.eventId,
    required this.productId,
    required this.code,
    required this.holderName,
    required this.holderEmail,
    required this.status,
    required this.issuedAt,
    this.usedAt,
    this.cancelledAt,
    this.eventName,
    this.productName,
  });

  final String id;
  final String orderId;
  final String eventId;
  final String productId;
  final String code;
  final String holderName;
  final String holderEmail;
  final String status;
  final DateTime issuedAt;
  final DateTime? usedAt;
  final DateTime? cancelledAt;
  final String? eventName;
  final String? productName;

  bool get isValid => status == 'issued';
  bool get isUsed => status == 'used';

  factory SambaTicket.fromMap(Map<String, dynamic> map) {
    final event = map['events'] as Map<String, dynamic>?;
    final product = map['campaign_products'] as Map<String, dynamic>?;
    return SambaTicket(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      eventId: map['event_id'] as String,
      productId: map['campaign_product_id'] as String,
      code: map['code'] as String,
      holderName: map['holder_name'] as String,
      holderEmail: map['holder_email'] as String,
      status: map['status'] as String,
      issuedAt: DateTime.parse(map['issued_at'].toString()),
      usedAt: map['used_at'] == null
          ? null
          : DateTime.tryParse(map['used_at'].toString()),
      cancelledAt: map['cancelled_at'] == null
          ? null
          : DateTime.tryParse(map['cancelled_at'].toString()),
      eventName: event?['name'] as String?,
      productName: product?['name'] as String?,
    );
  }
}
