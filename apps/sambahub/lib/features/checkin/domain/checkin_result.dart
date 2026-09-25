// checkin_result.dart
//
// CHANGELOG
// 2026-09-25 — Item 8 (Check-in), Handoff 08:
//   - Adicionado campo `kind` (QrKind, de qr_service.dart) para o widget
//     saber se o resultado é de ingresso ou de produto do catálogo, sem
//     precisar inferir isso pela presença/ausência de campos.
//   - Adicionados productName, quantityRedeemedNow, remainingBalance e
//     status, populados a partir do envelope de redeem-catalog-item
//     (confirmado no código-fonte da function: accepted, product_name,
//     quantity_redeemed_now, remaining_balance, status).
//   - fromMap() passa a receber `kind` explicitamente (quem chama já sabe
//     qual Edge Function foi invocada) em vez de tentar adivinhar pelo
//     conteúdo do mapa.
//   - Campos de ingresso (ticketId, ticketCode, holderName, checkedInAt)
//     mantidos sem alteração de comportamento.

import '../../../shared/services/qr_service.dart';

class CheckinResult {
  const CheckinResult({
    required this.kind,
    required this.accepted,
    required this.message,
    this.ticketId,
    this.ticketCode,
    this.holderName,
    this.eventId,
    this.checkedInAt,
    this.productName,
    this.quantityRedeemedNow,
    this.remainingBalance,
    this.status,
  });

  final QrKind kind;
  final bool accepted;
  final String message;

  // Campos de ingresso (kind == QrKind.ticket).
  final String? ticketId;
  final String? ticketCode;
  final String? holderName;
  final String? eventId;
  final DateTime? checkedInAt;

  // Campos de produto do catálogo (kind == QrKind.product).
  final String? productName;
  final int? quantityRedeemedNow;
  final int? remainingBalance;
  final String? status;

  factory CheckinResult.fromMap(QrKind kind, Map<String, dynamic> map) {
    return CheckinResult(
      kind: kind,
      accepted: map['accepted'] as bool? ?? map['valid'] as bool? ?? false,
      message: map['message'] as String? ?? 'Resultado da validação recebido.',
      ticketId: map['ticket_id'] as String?,
      ticketCode: map['ticket_code'] as String?,
      holderName: map['holder_name'] as String?,
      eventId: map['event_id'] as String?,
      checkedInAt: map['checked_in_at'] == null
          ? null
          : DateTime.tryParse(map['checked_in_at'].toString()),
      productName: map['product_name'] as String?,
      quantityRedeemedNow: (map['quantity_redeemed_now'] as num?)?.toInt(),
      remainingBalance: (map['remaining_balance'] as num?)?.toInt(),
      status: map['status'] as String?,
    );
  }
}