import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/app_notification.dart';

final class NotificationsRepository {
  NotificationsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<List<AppNotification>> list({String? tenantId}) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    final response = tenantId == null || tenantId.isEmpty
        ? await _client
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
        : await _client
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('tenant_id', tenantId)
            .order('created_at', ascending: false);
    return response.map(AppNotification.fromMap).toList(growable: false);
  }

  Future<void> markAsRead(String id) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> markAllAsRead({String? tenantId}) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final update = _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()});
    if (tenantId == null || tenantId.isEmpty) {
      await update.eq('user_id', userId).filter('read_at', 'is', null);
    } else {
      await update
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .filter('read_at', 'is', null);
    }
  }
}
