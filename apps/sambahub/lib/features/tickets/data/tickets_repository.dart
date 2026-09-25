import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/ticket.dart';

final class TicketsRepository {
  TicketsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<SambaTicket>> list(
      {required String tenantId, String? eventId}) async {
    var query = _client
        .from('tickets')
        .select('*, events(name), campaign_products(name)')
        .eq('tenant_id', tenantId);
    if (eventId != null && eventId.isNotEmpty)
      query = query.eq('event_id', eventId);
    final rows = await query.order('issued_at', ascending: false);
    return rows.map(SambaTicket.fromMap).toList(growable: false);
  }

  Future<SambaTicket> findByCode(
      {required String tenantId, required String code}) async {
    final row = await _client
        .from('tickets')
        .select('*, events(name), campaign_products(name)')
        .eq('tenant_id', tenantId)
        .eq('code', code.trim())
        .single();
    return SambaTicket.fromMap(row);
  }
}
