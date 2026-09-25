import '../services/edge_function_service.dart';

/// Cliente de rede para chamadas às Edge Functions do SambaHub.
final class EdgeFunctionClient {
  EdgeFunctionClient({EdgeFunctionService? service})
      : _service = service ?? EdgeFunctionService();

  final EdgeFunctionService _service;

  Future<Map<String, dynamic>> validateTicket({
    required String code,
    required String eventId,
  }) {
    return _service.invoke(
      'validate-ticket',
      body: {
        'ticket_code': code.trim(),
        'event_id': eventId,
      },
    );
  }

  Future<Map<String, dynamic>> createCheckout({
    required String campaignId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customer,
  }) {
    return _service.invoke(
      'create-checkout',
      body: {
        'campaign_id': campaignId,
        'items': items,
        'customer': customer,
      },
    );
  }

  Future<Map<String, dynamic>> reportSummary({
    required String tenantId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return _service.invoke(
      'get-tenant-report-summary',
      body: {
        'tenant_id': tenantId,
        'period_start': periodStart.toUtc().toIso8601String(),
        'period_end': periodEnd.toUtc().toIso8601String(),
      },
    );
  }
}
