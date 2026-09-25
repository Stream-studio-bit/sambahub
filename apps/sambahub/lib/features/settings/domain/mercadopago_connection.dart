// lib/features/settings/domain/mercadopago_connection.dart
//
// CHANGELOG
// 2026-09-21: Criação. Modelo do estado da conexão Mercado Pago do tenant,
// espelhando exatamente o payload de mp-marketplace-oauth (actions status/
// connect/disconnect/refresh) — nunca contém access_token/refresh_token,
// que a Edge Function jamais devolve ao Flutter.

enum MercadoPagoConnectionStatus {
  disconnected,
  connected,
  expired,
  error;

  static MercadoPagoConnectionStatus fromRaw(String raw) {
    return switch (raw) {
      'connected' => MercadoPagoConnectionStatus.connected,
      'expired' => MercadoPagoConnectionStatus.expired,
      'error' => MercadoPagoConnectionStatus.error,
      _ => MercadoPagoConnectionStatus.disconnected,
    };
  }
}

class MercadoPagoConnection {
  const MercadoPagoConnection({
    required this.status,
    this.mpUserIdMasked,
    this.connectedAt,
  });

  final MercadoPagoConnectionStatus status;

  /// Já vem mascarado da Edge Function (ex.: "••••1234"). Nunca é o
  /// mp_user_id completo.
  final String? mpUserIdMasked;

  final DateTime? connectedAt;

  factory MercadoPagoConnection.fromMap(Map<String, dynamic> map) {
    final rawConnectedAt = map['connected_at'] as String?;
    return MercadoPagoConnection(
      status: MercadoPagoConnectionStatus.fromRaw(map['status'] as String),
      mpUserIdMasked: map['mp_user_id'] as String?,
      connectedAt: rawConnectedAt == null ? null : DateTime.tryParse(rawConnectedAt),
    );
  }
}