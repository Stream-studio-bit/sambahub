// qr_service.dart
//
// CHANGELOG
// 2026-09-25: Reescrito por completo. Diagnóstico confirmou que o formato
// anterior (sambahub://ticket?id=...&event=...) NUNCA é gerado pelo app —
// não há nenhum código de geração de QR no projeto (pubspec.yaml só tem
// mobile_scanner, leitor) nem no backend (tickets_page.dart só exibe
// ticket.code como texto puro; issue-tickets nunca monta essa URI). Era
// código morto, incompatível com o que o check-in de fato lê: o texto cru
// de tickets.code (base64url, sem prefixo, gerado por issue-tickets) ou
// de catalog_redemptions.code (mesma forma, mas com prefixo "P-", gerado
// por issue-catalog-redemptions).
//
// Decisão do usuário (2026-09-25): distinguir ingresso de produto pelo
// PREFIXO do código lido, sem tentar dois endpoints em sequência. Código
// de produto sempre começa com "P-"; código de ingresso nunca tem esse
// prefixo (formato já em produção, não alterado). Por isso QrService não
// decodifica mais uma URI — só classifica o texto lido e devolve o código
// exatamente como deve ser enviado ao servidor (validate-ticket para
// QrKind.ticket, redeem-catalog-item para QrKind.product).
//
// buildTicketPayload() foi removido: montava a URI do formato antigo, que
// nunca foi consumida por nada real.

enum QrKind { ticket, product }

class QrPayload {
  const QrPayload({required this.rawValue, required this.code, required this.kind});

  /// Texto exatamente como lido da câmera ou digitado manualmente.
  final String rawValue;

  /// Código a enviar ao servidor: igual a [rawValue] hoje (o prefixo "P-",
  /// quando existe, faz parte do código de produto e deve ser enviado como
  /// está — catalog_redemptions.code é gravado com o prefixo incluído).
  final String code;

  final QrKind kind;

  bool get isTicket => kind == QrKind.ticket;
  bool get isProduct => kind == QrKind.product;
}

abstract final class QrService {
  static const String productPrefix = 'P-';

  static QrPayload parse(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      throw const QrException('O QR Code está vazio.');
    }

    if (value.startsWith(productPrefix)) {
      return QrPayload(rawValue: value, code: value, kind: QrKind.product);
    }

    return QrPayload(rawValue: value, code: value, kind: QrKind.ticket);
  }
}

final class QrException implements Exception {
  const QrException(this.message);

  final String message;

  @override
  String toString() => 'QrException: $message';
}