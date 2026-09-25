// CHANGELOG
// 2026-09-19: Criado no mesmo padrão de whatsapp_service.dart — classe
// estática, sem estado, devolvendo um Uri pronto para abrir com url_launcher.
// Diferente de Facebook/Telegram, o intent do X aceita texto sem link (usado
// no compartilhamento de eventos, que não têm uma página pública própria).

import 'share_service.dart';

abstract final class XService {
  static Uri buildShareUri({String? url, String? text}) {
    return Uri.parse('https://twitter.com/intent/tweet').replace(
      queryParameters: {
        if (url != null && url.trim().isNotEmpty) 'url': url.trim(),
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      },
    );
  }

  static Uri buildCampaignUri({
    required String campaignName,
    required String campaignUrl,
  }) {
    final payload = SharePayload(
      title: campaignName,
      text: 'Confira esta campanha de samba no SambaHub:',
    );
    return buildShareUri(url: campaignUrl, text: payload.content);
  }

  static Uri buildTextUri({required String title, required String text}) {
    final payload = SharePayload(title: title, text: text);
    return buildShareUri(text: payload.content);
  }
}