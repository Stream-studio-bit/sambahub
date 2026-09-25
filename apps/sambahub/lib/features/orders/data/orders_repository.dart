// Changelog:
// 2026-09-18: Item 10 (Orders) — select passa a incluir payment_transactions
// (join por order_id, mesmo padrão de tickets_repository.dart com
// events/campaign_products). Faltava a "transação vinculada ao pedido"
// exigida pelo item 10; nenhuma lógica financeira foi criada no Flutter,
// só leitura do que já existe em payment_transactions.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/order.dart';

final class OrdersRepository {
  OrdersRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<SambaOrder>> list({required String tenantId}) async {
    final rows = await _client
        .from('orders')
        .select('*, order_items(*), payment_transactions(*)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return rows.map(SambaOrder.fromMap).toList(growable: false);
  }

  Future<SambaOrder> findById(
      {required String tenantId, required String id}) async {
    final row = await _client
        .from('orders')
        .select('*, order_items(*), payment_transactions(*)')
        .eq('tenant_id', tenantId)
        .eq('id', id)
        .single();
    return SambaOrder.fromMap(row);
  }
}