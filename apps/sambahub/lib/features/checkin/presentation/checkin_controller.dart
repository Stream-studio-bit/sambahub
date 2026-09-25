// checkin_controller.dart
//
// CHANGELOG
// 2026-09-25 — Item 8 (Check-in), Handoff 08:
//   - validate() renomeado para checkin() e passa a receber o código bruto
//     lido (rawCode) em vez de assumir que é sempre um ingresso. Usa
//     QrService.parse() (já reescrito e aprovado) para classificar o código
//     (QrKind.ticket vs QrKind.product) e despachar para
//     CheckinRepository.validateTicket() ou .redeemCatalogItem().
//   - Adicionado parâmetro `quantity` (padrão 1), repassado somente para
//     redeemCatalogItem() — ingresso não usa quantidade.
//   - CheckinResult.fromMap() agora recebe o QrKind explicitamente, vindo
//     do resultado do parse, não mais inferido.
//   - QrException (código vazio) vira AsyncError tratado, sem chamar
//     nenhuma Edge Function.
//   - checkinRepositoryProvider e checkinEventNameProvider mantidos sem
//     alteração de comportamento (item 8, 2026-09-18).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/qr_service.dart';
import '../data/checkin_repository.dart';
import '../domain/checkin_result.dart';

final checkinRepositoryProvider = Provider<CheckinRepository>(
  (ref) => CheckinRepository(),
);

final checkinEventNameProvider =
    FutureProvider.family<String?, String>((ref, eventId) {
  return ref.read(checkinRepositoryProvider).eventName(eventId);
});

final checkinControllerProvider =
    NotifierProvider<CheckinController, AsyncValue<CheckinResult?>>(
  CheckinController.new,
);

class CheckinController extends Notifier<AsyncValue<CheckinResult?>> {
  CheckinRepository get _repository => ref.read(checkinRepositoryProvider);

  @override
  AsyncValue<CheckinResult?> build() => const AsyncData(null);

  Future<void> checkin({
    required String rawCode,
    required String eventId,
    required String tenantId,
    int quantity = 1,
  }) async {
    final QrPayload payload;
    try {
      payload = QrService.parse(rawCode);
    } on QrException catch (e) {
      state = AsyncError(Exception(e.message), StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (payload.isTicket) {
        final result = await _repository.validateTicket(
          code: payload.code,
          eventId: eventId,
          tenantId: tenantId,
        );
        return CheckinResult.fromMap(QrKind.ticket, {
          ...result,
          'ticket_code': result['ticket_code'] ?? payload.code,
          'event_id': result['event_id'] ?? eventId,
          'accepted': result['accepted'] ?? true,
        });
      }

      final result = await _repository.redeemCatalogItem(
        code: payload.code,
        eventId: eventId,
        tenantId: tenantId,
        quantity: quantity,
      );
      return CheckinResult.fromMap(QrKind.product, {
        ...result,
        'event_id': result['event_id'] ?? eventId,
        'accepted': result['accepted'] ?? true,
      });
    });
  }

  void reset() => state = const AsyncData(null);
}