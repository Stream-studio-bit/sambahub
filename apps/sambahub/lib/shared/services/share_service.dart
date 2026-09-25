// CHANGELOG
// 2026-09-19: Removido o import direto de package:cross_file/cross_file.dart
// — share_plus já reexporta XFile, então era redundante (unnecessary_import)
// e apontava pra um pacote não declarado direto no pubspec.yaml
// (depend_on_referenced_packages), só chega via share_plus. XFile continua
// disponível pela mesma referência ao tipo, sem mudança de comportamento.
// 2026-09-19: Adicionado ShareService.shareNative — o "adapter nativo de
// share" que o doc desta classe já previa, agora conectado via share_plus
// (Share.share/Share.shareXFiles). copyToClipboard não foi alterado.

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class SharePayload {
  const SharePayload({required this.title, required this.text, this.url});

  final String title;
  final String text;
  final String? url;

  String get content => [
        title.trim(),
        text.trim(),
        if (url != null && url!.trim().isNotEmpty) url!.trim(),
      ].where((value) => value.isNotEmpty).join('\n\n');
}

/// Serviço de compartilhamento sem acoplar o domínio a um plugin específico.
///
/// A camada de UI pode usar [copyToClipboard] agora e conectar um adapter
/// nativo de share posteriormente sem alterar os contratos do domínio.
abstract final class ShareService {
  static Future<void> copyToClipboard(SharePayload payload) async {
    final content = payload.content;
    if (content.isEmpty) {
      throw const ShareException('Não há conteúdo para compartilhar.');
    }
    await Clipboard.setData(ClipboardData(text: content));
  }

  /// Adapter nativo de share (share_plus), conforme previsto no doc desta
  /// classe. Com [files], usa a folha nativa de compartilhamento de arquivos
  /// (Share.shareXFiles); sem eles, compartilha só o texto (Share.share).
  static Future<void> shareNative(SharePayload payload,
      {List<XFile>? files}) async {
    final content = payload.content;
    if (content.isEmpty && (files == null || files.isEmpty)) {
      throw const ShareException('Não há conteúdo para compartilhar.');
    }
    if (files != null && files.isNotEmpty) {
      await Share.shareXFiles(files,
          text: content.isEmpty ? null : content, subject: payload.title);
    } else {
      await Share.share(content, subject: payload.title);
    }
  }
}

final class ShareException implements Exception {
  const ShareException(this.message);

  final String message;

  @override
  String toString() => 'ShareException: $message';
}