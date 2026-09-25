class ReportSummary {
  const ReportSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.ordersCount,
    required this.paidOrdersCount,
    required this.ticketsIssued,
    required this.ticketsCheckedIn,
    required this.grossRevenue,
    required this.platformFees,
    required this.netRevenue,
    required this.refundedAmount,
    this.eventsCount = 0,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final int ordersCount;
  final int paidOrdersCount;
  final int ticketsIssued;
  final int ticketsCheckedIn;
  final String grossRevenue;
  final String platformFees;
  final String netRevenue;
  final String refundedAmount;
  final int eventsCount;

  double get paymentConversionRate =>
      ordersCount == 0 ? 0 : paidOrdersCount / ordersCount;
  double get checkinRate =>
      ticketsIssued == 0 ? 0 : ticketsCheckedIn / ticketsIssued;

  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    return ReportSummary(
      periodStart: DateTime.parse(map['period_start'].toString()),
      periodEnd: DateTime.parse(map['period_end'].toString()),
      ordersCount: _int(map['orders_count']),
      paidOrdersCount: _int(map['paid_orders_count']),
      ticketsIssued: _int(map['tickets_issued']),
      ticketsCheckedIn: _int(map['tickets_checked_in']),
      grossRevenue: map['gross_revenue']?.toString() ?? '0.00',
      platformFees: map['platform_fees']?.toString() ?? '0.00',
      netRevenue: map['net_revenue']?.toString() ?? '0.00',
      refundedAmount: map['refunded_amount']?.toString() ?? '0.00',
      eventsCount: _int(map['events_count']),
    );
  }

  static int _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
