import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/samba_group.dart';

final class GroupsRepository {
  GroupsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<SambaGroup>> list({required String tenantId}) async {
    final rows = await _client
        .from('groups')
        .select()
        .eq('tenant_id', tenantId)
        .order('name');
    return rows.map(SambaGroup.fromMap).toList(growable: false);
  }

  Future<SambaGroup> create({
    required String tenantId,
    required String name,
    required String slug,
    String? description,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
  }) async {
    final row = await _client
        .from('groups')
        .insert({
          'tenant_id': tenantId,
          'name': name.trim(),
          'slug': slug.trim().toLowerCase(),
          'description': _nullable(description),
          'contact_name': _nullable(contactName),
          'contact_email': _nullable(contactEmail),
          'contact_phone': _nullable(contactPhone),
          'is_active': true,
        })
        .select()
        .single();
    return SambaGroup.fromMap(row);
  }

  Future<SambaGroup> update({
    required String id,
    required String name,
    required String slug,
    String? description,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    required bool isActive,
  }) async {
    final row = await _client
        .from('groups')
        .update({
          'name': name.trim(),
          'slug': slug.trim().toLowerCase(),
          'description': _nullable(description),
          'contact_name': _nullable(contactName),
          'contact_email': _nullable(contactEmail),
          'contact_phone': _nullable(contactPhone),
          'is_active': isActive,
        })
        .eq('id', id)
        .select()
        .single();
    return SambaGroup.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from('groups').delete().eq('id', id);
  }

  String? _nullable(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
