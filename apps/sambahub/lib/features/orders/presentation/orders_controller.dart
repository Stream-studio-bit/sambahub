import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/orders_repository.dart';
import '../domain/order.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(),
);

final ordersControllerProvider =
    AsyncNotifierProviderFamily<OrdersController, List<SambaOrder>, String>(
  OrdersController.new,
);

class OrdersController extends FamilyAsyncNotifier<List<SambaOrder>, String> {
  OrdersRepository get _repository => ref.read(ordersRepositoryProvider);

  @override
  Future<List<SambaOrder>> build(String tenantId) {
    return _repository.list(tenantId: tenantId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.list(tenantId: arg));
  }
}
