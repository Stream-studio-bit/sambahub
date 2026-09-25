import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/payment_transaction.dart';

final class PaymentsRepository {
  PaymentsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<PaymentTransaction>> list({required String tenantId}) async {
    final rows = await _client
        .from('payment_transactions')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return rows.map(PaymentTransaction.fromMap).toList(growable: false);
  }

  Future<PaymentTransaction> findByOrder({
    required String tenantId,
    required String orderId,
  }) async {
    final row = await _client
        .from('payment_transactions')
        .select()
        .eq('tenant_id', tenantId)
        .eq('order_id', orderId)
        .single();
    return PaymentTransaction.fromMap(row);
  }
}
