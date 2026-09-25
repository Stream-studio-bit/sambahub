// lib/core/utils/slug.dart
// CHANGELOG
// 2026-09-23: Criado. Extrai a normalização de slug que faltava em
// CampaignsRepository.create()/update() (antes só trim()+toLowerCase(),
// permitindo espaço e acento no slug salvo — causa raiz confirmada do link
// quebrado "/luuma-restaurante/samba com feijoada"). Mesma lógica do
// slugify() em supabase/functions/provision-workspace/index.ts (minúsculas,
// remove acentos, troca qualquer sequência de caracteres fora [a-z0-9] por
// um único hífen, corta em 56 caracteres ANTES de remover hífen da ponta,
// pra não deixar "-" sobrando no final). Sem dependência externa — mapa de
// acentuação manual em vez de String.normalize, que não existe em
// dart:core (é API de JS/Web, não do Dart puro).
// Usado em CampaignsRepository.create()/update() (normalização real antes
// de salvar) e nos formulários de campanha (campaigns_admin_page.dart,
// campaign_detail_page.dart) para o preview "Link: /.../..." mostrar o
// formato final enquanto o usuário digita.

const Map<String, String> _diacriticsMap = {
  'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y',
};

String _removeDiacritics(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticsMap[char] ?? char);
  }
  return buffer.toString();
}

/// Normaliza [value] para um slug de URL: minúsculas, sem acentos,
/// qualquer sequência de caracteres fora [a-z0-9] vira um único hífen, sem
/// hífen nas pontas. Espelha o slugify() de
/// supabase/functions/provision-workspace/index.ts (mesmo limite de 56
/// caracteres, cortado antes de remover hífen da ponta).
///
/// Não tem fallback tipo "sambahub" (como o do provision-workspace) porque
/// os formulários que chamam isso já validam campo obrigatório — um slug
/// vazio aqui deve falhar a validação do formulário, não virar um valor
/// mágico.
String slugify(String value) {
  final lower = _removeDiacritics(value.toLowerCase());
  final hyphenated = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final sliced = hyphenated.length > 56 ? hyphenated.substring(0, 56) : hyphenated;
  return sliced.replaceAll(RegExp(r'^-+'), '').replaceAll(RegExp(r'-+$'), '');
}