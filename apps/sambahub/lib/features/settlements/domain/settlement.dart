class Settlement {
  const Settlement({
    required this.id,
    required this.tenantId,
    required this.reference,
    required this.status,
    required this.grossAmount,
    required this.platformFee,
    required this.paymentFee,
    required this.venueAmount,
    required this.groupAmount,
    required this.netAmount,
    required this.currency,
    required this.createdAt,
    this.scheduledAt,
    this.paidAt,
    this.eventId,
    this.groupId,
  });

  final String id;
  final String tenantId;
  final String reference;
  final String status;
  final String grossAmount;
  final String platformFee;
  final String paymentFee;
  final String venueAmount;
  final String groupAmount;
  final String netAmount;
  final String currency;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? paidAt;
  final String? eventId;
  final String? groupId;

  bool get isPaid => status == 'paid';

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      reference: map['reference'] as String,
      status: map['status'] as String,
      grossAmount: map['gross_amount'].toString(),
      platformFee: map['platform_fee'].toString(),
      paymentFee: map['payment_fee'].toString(),
      venueAmount: map['venue_amount'].toString(),
      groupAmount: map['group_amount'].toString(),
      netAmount: map['net_amount'].toString(),
      currency: map['currency'] as String? ?? 'BRL',
      createdAt: DateTime.parse(map['created_at'].toString()),
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.tryParse(map['scheduled_at'].toString()),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.tryParse(map['paid_at'].toString()),
      eventId: map['event_id'] as String?,
      groupId: map['group_id'] as String?,
    );
  }
}
