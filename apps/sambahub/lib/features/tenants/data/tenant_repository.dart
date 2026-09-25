// CHANGELOG
// 2026-09-18: Provisionamento automático de organização no primeiro login.
// - Adicionado defaultWorkspaceName(): nome padrão da organização do usuário
//   logado (user_metadata.name; senão parte local do e-mail; senão
//   'Minha organização'). Retorna null quando não há usuário logado.
// - listForCurrentUser() e update() sem alteração.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/tenant.dart';

final class TenantRepository {
  TenantRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<Tenant>> listForCurrentUser() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from('tenant_memberships')
        .select('role, status, tenant_id, tenants(*)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at');

    return rows
        .map((row) => Tenant.fromMembershipMap(row))
        .where((tenant) => tenant.isActive)
        .toList(growable: false);
  }

  /// Nome padrão para a organização criada automaticamente no primeiro login.
  String? defaultWorkspaceName() {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final metadataName = user.userMetadata?['name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }

    final email = user.email;
    if (email != null && email.contains('@')) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }
    return 'Minha organização';
  }

  Future<Tenant> update({
    required String id,
    required String name,
    String? legalName,
    String? email,
    String? phone,
  }) async {
    final row = await _client
        .from('tenants')
        .update({
          'name': name.trim(),
          'legal_name': _nullable(legalName),
          'email': _nullable(email),
          'phone': _nullable(phone),
        })
        .eq('id', id)
        .select()
        .single();

    return Tenant(
      id: row['id'] as String,
      name: row['name'] as String,
      slug: row['slug'] as String,
      status: row['status'] as String,
      role: 'owner',
      legalName: row['legal_name'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
    );
  }

  String? _nullable(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}