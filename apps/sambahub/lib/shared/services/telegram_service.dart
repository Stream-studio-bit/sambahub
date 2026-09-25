// CHANGELOG
// 2026-09-19: Criado no mesmo padrão de whatsapp_service.dart — classe
// estática, sem estado, devolvendo um Uri pronto para abrir com url_launcher.

import 'share_service.dart';

abstract final class TelegramService {
  static Uri buildShareUri({required String url, String? text}) {
    return Uri.parse('https://t.me/share/url').replace(
      queryParameters: {
        'url': url,
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
}