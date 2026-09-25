import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/payments_repository.dart';
import '../domain/payment_transaction.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(),
);

final paymentsControllerProvider = AsyncNotifierProviderFamily<
    PaymentsController, List<PaymentTransaction>, String>(
  PaymentsController.new,
);

class PaymentsController
    extends FamilyAsyncNotifier<List<PaymentTransaction>, String> {
  PaymentsRepository get _repository => ref.read(paymentsRepositoryProvider);

  @override
  Future<List<PaymentTransaction>> build(String tenantId) {
    return _repository.list(tenantId: tenantId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.list(tenantId: arg));
  }
}
