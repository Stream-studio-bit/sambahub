import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tickets_repository.dart';
import '../domain/ticket.dart';

final ticketsRepositoryProvider = Provider<TicketsRepository>(
  (ref) => TicketsRepository(),
);

final ticketsControllerProvider = AsyncNotifierProviderFamily<TicketsController,
    List<SambaTicket>, TicketQuery>(
  TicketsController.new,
);

class TicketQuery {
  const TicketQuery({required this.tenantId, this.eventId});
  final String tenantId;
  final String? eventId;

  @override
  bool operator ==(Object other) =>
      other is TicketQuery &&
      other.tenantId == tenantId &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(tenantId, eventId);
}

class TicketsController
    extends FamilyAsyncNotifier<List<SambaTicket>, TicketQuery> {
  TicketsRepository get _repository => ref.read(ticketsRepositoryProvider);

  @override
  Future<List<SambaTicket>> build(TicketQuery query) {
    return _repository.list(tenantId: query.tenantId, eventId: query.eventId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => _repository.list(tenantId: arg.tenantId, eventId: arg.eventId));
  }
}
