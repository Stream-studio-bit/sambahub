import 'share_service.dart';

abstract final class WhatsappService {
  static Uri buildShareUri({
    required String message,
    String? phoneNumber,
  }) {
    final normalizedPhone = _normalizePhone(phoneNumber);
    final base = normalizedPhone == null
        ? 'https://wa.me/'
        : 'https://wa.me/$normalizedPhone';
    return Uri.parse(base).replace(queryParameters: {'text': message.trim()});
  }

  static Uri buildCampaignUri({
    required String campaignName,
    required String campaignUrl,
    String? phoneNumber,
  }) {
    final payload = SharePayload(
      title: campaignName,
      text: 'Aqui no SambaHub, o samba tem dia e local marcado:',
      url: campaignUrl,
    );
    return buildShareUri(
      message: payload.content,
      phoneNumber: phoneNumber,
    );
  }

  static String? _normalizePhone(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) return null;
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10 || digits.length > 15) {
      throw const ShareException('Número de WhatsApp inválido.');
    }
    return digits;
  }
}
