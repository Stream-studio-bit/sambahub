import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(),
);

final notificationsControllerProvider = AsyncNotifierProviderFamily<
    NotificationsController, List<AppNotification>, String?>(
  NotificationsController.new,
);

class NotificationsController
    extends FamilyAsyncNotifier<List<AppNotification>, String?> {
  NotificationsRepository get _repository =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<List<AppNotification>> build(String? tenantId) {
    return _repository.list(tenantId: tenantId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.list(tenantId: arg));
  }

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    await refresh();
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead(tenantId: arg);
    await refresh();
  }
}
