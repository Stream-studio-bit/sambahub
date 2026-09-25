// CHANGELOG
// 2026-09-19: Criado no mesmo padrão de whatsapp_service.dart — classe
// estática, sem estado, devolvendo um Uri pronto para abrir com url_launcher.
// O sharer do Facebook é essencialmente um diálogo de link (parâmetro "u"
// obrigatório); "quote" é o texto de acompanhamento, opcional.

import 'share_service.dart';

abstract final class FacebookService {
  static Uri buildShareUri({required String url, String? quote}) {
    return Uri.parse('https://www.facebook.com/sharer/sharer.php').replace(
      queryParameters: {
        'u': url,
        if (quote != null && quote.trim().isNotEmpty) 'quote': quote.trim(),
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
    return buildShareUri(url: campaignUrl, quote: payload.content);
  }
}