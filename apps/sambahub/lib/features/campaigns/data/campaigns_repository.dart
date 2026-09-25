// CHANGELOG
// 2026-09-23 (2): Função remover campanha (soft delete, confirmado via
// information_schema que campaigns.deleted_at já existe e que
// campaign_products/orders são FK RESTRICT em campaign_id — delete físico
// falharia sempre que houver produto ou pedido, e toda campanha nasce com o
// produto VIP quando o evento tem vip_quantity > 0; campaign_favorites é
// CASCADE mas não muda a decisão). Adicionado remove(id). listAdmin() já
// filtrava .isFilter('deleted_at', null) (nenhuma mudança necessária ali).
// findByTenantAndCampaignSlug() (página pública) NÃO filtrava — corrigido
// para também usar .isFilter('deleted_at', null), senão o link público de
// uma campanha removida continuaria acessível normalmente.
// 2026-09-23: Duas correções:
// - create()/update() agora normalizam o slug com slugify() (lib/core/utils/slug.dart)
//   em vez de só slug.trim().toLowerCase(). Causa raiz confirmada do link quebrado
//   "/luuma-restaurante/samba com feijoada": o antigo trim+lowercase deixava espaço
//   e acento passar direto pro banco. slugify() troca qualquer sequência fora
//   [a-z0-9] por hífen (mesma lógica do slugify() de provision-workspace/index.ts).
//   Normalização feita aqui no repositório (não só no formulário) pra cobrir
//   qualquer chamador futuro, não só a UI atual.
// - listEvents() passou a trazer description e cover_image_path (colunas
//   confirmadas via information_schema.columns em events), usadas pelo
//   formulário de criação de campanha para pré-preencher nome/descrição a
//   partir do evento escolhido, sem o usuário redigitar.
// 2026-09-22: Link público de campanha trocado de /c/:slug para
// /:tenantSlug/:campaignSlug (decisão do usuário — ver router.dart).
// - findBySlug(slug) removido, substituído por
//   findByTenantAndCampaignSlug({tenantSlug, campaignSlug}): usa
//   tenants!inner(slug) no embed e filtra .eq('tenants.slug', tenantSlug)
//   além do .eq('slug', campaignSlug) que já existia. campaigns.tenant_id é
//   FK de tenants (já usado em create()), então o inner join é seguro.
// - listEvents() passou a trazer a coluna slug (antes só id, name,
//   starts_at, status), para o formulário de criação de campanha poder
//   pré-preencher o slug da campanha com o slug do evento escolhido.
// - listAdmin() e getAdmin() agora trazem tenants(slug) no embed (campos
//   novos: item['tenants']['slug']), necessário para as telas de admin
//   (campaigns_admin_page.dart, campaign_detail_page.dart) montarem o
//   preview do link público e o link de compartilhamento no novo formato.
// - Adicionado getTenantSlug(tenantId): busca direta em tenants (sem
//   depender de uma campanha existir), usada pelo formulário de criação de
//   campanha para montar o preview "/<tenantSlug>/<slug>" mesmo quando o
//   tenant ainda não tem nenhuma campanha (logo, sem embed tenants(slug)
//   disponível via listAdmin).
// 2026-09-20: Favoritos da campanha pública. Adicionados getFavoriteState() e
// toggleFavorite(), que chamam as functions do banco fn_get_campaign_favorites
// e fn_toggle_campaign_favorite (migration 2026_09_20_campaign_favorites.sql)
// e devolvem ({count, favorited}). Nenhuma outra lógica alterada.
// 2026-09-20: create() gera o produto VIP da campanha. Após inserir a
// campanha, lê events.vip_quantity do evento escolhido; se > 0, insere em
// campaign_products um produto type='vip', price=0 (convite gratuito),
// stock_quantity = vip_quantity, is_active=true, nome "Convite VIP". Os dois
// inserts não são atômicos: se o do produto falhar, a campanha já existe (o
// erro sobe para o chamador). Alterar events.vip_quantity depois não
// atualiza o produto — o estoque passa a ser editado no detalhe da
// campanha. Nenhuma outra lógica alterada.
// 2026-09-20: findBySlug — embed events(...) agora inclui cover_image_path.
// Causa raiz (confirmada via SQL): campaigns.cover_image_path é null e o flyer
// fica só em events.cover_image_path; o embed não o trazia, então o flyer
// nunca chegava ao PublicCampaign (fallback em public_campaign.dart).
// Nenhuma outra lógica alterada.
// 2026-09-20: Duas mudanças para a campanha pública:
// - Adicionado getCoverImageUrl(path): cover_image_path é um path de storage
//   (confirmado: '<tenant_id>/<campaign_id>.png', mesmo padrão de
//   events.cover_image_path), não uma URL. O bucket é 'event-covers' e é
//   PUBLIC (confirmado no painel do Storage), então a resolução é
//   getPublicUrl() simples — sem signed URL. Mesma responsabilidade que
//   events_repository.dart::getCoverImageUrl(), replicada aqui porque
//   PublicCampaignPage usa CampaignsRepository, não EventsRepository.
// - createPublicOrder() ganhou o parâmetro catalogProducts (default {}),
//   repassado como 'catalog_products' no body da function create-public-order
//   (ver CHANGELOG de create-public-order/index.ts, 2026-09-20). Chamadas
//   existentes que não passam catalogProducts continuam funcionando igual —
//   o pedido só tem itens tipo 'ticket'.
// - Corrigido: .is('deleted_at', null) não compila — 'is' é palavra reservada em Dart.
//   Trocado pelo método correto do postgrest-dart: .isFilter('deleted_at', null)
//   (3 ocorrências: listAdmin, listEvents, listProducts)
// - Nenhuma outra lógica foi alterada
// 2026-09-18: Item 9 (Campaigns) — status enum confirmado no banco
// (campaigns_status_check: draft/published/paused/finished). Adicionados
// update() (edição de nome/slug/descrição — faltava por completo), pause()
// e finish(). publish() não foi duplicado: ele já seta status='published'
// a partir de qualquer status, então também serve para retomar uma campanha
// pausada (paused -> published), sem precisar de um método "resume" novo.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/slug.dart';
import '../domain/public_campaign.dart';

final class CampaignsRepository {
  CampaignsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;
  final SupabaseClient _client;

  static const String _coverBucket = 'event-covers';

  /// Resolve o path salvo em cover_image_path (ex.:
  /// '<tenant_id>/<campaign_id>.png') para a URL pública do bucket
  /// 'event-covers'. Retorna null se path for nulo/vazio.
  String? getCoverImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(_coverBucket).getPublicUrl(path);
  }

  /// Slug do tenant, usado para montar o preview do link público
  /// (/<tenantSlug>/<campaignSlug>) na tela de criação de campanha, antes de
  /// a campanha existir (e portanto antes de haver um embed tenants(slug)
  /// disponível via listAdmin/getAdmin).
  Future<String?> getTenantSlug(String tenantId) async {
    final row = await _client
        .from('tenants')
        .select('slug')
        .eq('id', tenantId)
        .maybeSingle();
    return row?['slug'] as String?;
  }

  Future<List<Map<String, dynamic>>> listAdmin({required String tenantId}) async {
    final rows = await _client
        .from('campaigns')
        .select('id, name, slug, status, starts_at, event_id, events(name), tenants(slug)')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listEvents({required String tenantId}) async {
    final rows = await _client
        .from('events')
        .select('id, name, slug, description, cover_image_path, starts_at, status')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .order('starts_at');
    return rows.cast<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Map<String, dynamic>> create({
    required String tenantId,
    required String eventId,
    required String name,
    required String slug,
    String? description,
  }) async {
    final campaign = await _client.from('campaigns').insert({
      'tenant_id': tenantId,
      'event_id': eventId,
      'name': name.trim(),
      'slug': slugify(slug),
      'description': description?.trim(),
      'status': 'draft',
    }).select().single();

    final event = await _client
        .from('events')
        .select('vip_quantity')
        .eq('id', eventId)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    final vipQuantity = (event?['vip_quantity'] as num?)?.toInt();
    if (vipQuantity != null && vipQuantity > 0) {
      await _client.from('campaign_products').insert({
        'tenant_id': tenantId,
        'campaign_id': campaign['id'],
        'name': 'Convite VIP',
        'type': 'vip',
        'price': 0,
        'stock_quantity': vipQuantity,
        'is_active': true,
      });
    }
    return campaign;
  }

  Future<void> publish(String id) async {
    await _client.from('campaigns').update({
      'status': 'published',
      'published_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> update({
    required String id,
    required String name,
    required String slug,
    String? description,
  }) async {
    await _client.from('campaigns').update({
      'name': name.trim(),
      'slug': slugify(slug),
      'description': description?.trim(),
    }).eq('id', id);
  }

  /// Remove (soft delete) a campanha. Delete físico não é viável:
  /// campaign_products e orders são FK RESTRICT em campaign_id (confirmado
  /// via information_schema), e toda campanha nasce com o produto VIP
  /// quando o evento tem vip_quantity > 0 — ou seja, delete físico falharia
  /// quase sempre. Mesmo padrão de deleteProduct().
  Future<void> remove(String id) async {
    await _client.from('campaigns').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> pause(String id) async {
    await _client.from('campaigns').update({'status': 'paused'}).eq('id', id);
  }

  Future<void> finish(String id) async {
    await _client.from('campaigns').update({'status': 'finished'}).eq('id', id);
  }

  Future<Map<String, dynamic>> getAdmin(String id) async {
    return await _client
        .from('campaigns')
        .select(
            'id, tenant_id, event_id, name, slug, description, status, starts_at, ends_at, campaign_products(*), tenants(slug)')
        .eq('id', id)
        .single();
  }

  Future<List<Map<String, dynamic>>> listProducts(String campaignId) async {
    final rows = await _client
        .from('campaign_products')
        .select('*')
        .eq('campaign_id', campaignId)
        .isFilter('deleted_at', null)
        .order('sort_order')
        .order('name');
    return rows.cast<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Map<String, dynamic>> createProduct({
    required String tenantId,
    required String campaignId,
    required String name,
    required String type,
    required String price,
    String? description,
    int? stockQuantity,
  }) async {
    return await _client.from('campaign_products').insert({
      'tenant_id': tenantId,
      'campaign_id': campaignId,
      'name': name.trim(),
      'type': type,
      'price': price.trim().replaceAll(',', '.'),
      'description': description?.trim(),
      'stock_quantity': stockQuantity,
      'is_active': true,
    }).select().single();
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String type,
    required String price,
    String? description,
    int? stockQuantity,
    required bool isActive,
  }) async {
    await _client.from('campaign_products').update({
      'name': name.trim(),
      'type': type,
      'price': price.trim().replaceAll(',', '.'),
      'description': description?.trim(),
      'stock_quantity': stockQuantity,
      'is_active': isActive,
    }).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('campaign_products').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'is_active': false,
    }).eq('id', id);
  }

  Future<({int count, bool favorited})> getFavoriteState({
    required String campaignId,
    required String deviceId,
  }) async {
    final rows = await _client.rpc('fn_get_campaign_favorites',
        params: {'p_campaign_id': campaignId, 'p_device_id': deviceId});
    return _parseFavoriteState(rows);
  }

  Future<({int count, bool favorited})> toggleFavorite({
    required String campaignId,
    required String deviceId,
  }) async {
    final rows = await _client.rpc('fn_toggle_campaign_favorite',
        params: {'p_campaign_id': campaignId, 'p_device_id': deviceId});
    return _parseFavoriteState(rows);
  }

  ({int count, bool favorited}) _parseFavoriteState(dynamic rows) {
    final row = rows is List && rows.isNotEmpty ? rows.first : rows;
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida dos favoritos.');
    }
    return (
      count: (row['favorite_count'] as num).toInt(),
      favorited: row['favorited'] as bool,
    );
  }

  /// Busca a campanha pública pelo par de slugs da URL
  /// (/:tenantSlug/:campaignSlug). tenants!inner(slug) força o join a
  /// existir (campaigns.tenant_id é FK obrigatória de tenants), permitindo
  /// filtrar por tenants.slug junto com o slug da própria campanha.
  Future<PublicCampaign> findByTenantAndCampaignSlug({
    required String tenantSlug,
    required String campaignSlug,
  }) async {
    final row = await _client
        .from('campaigns')
        .select(
            '*, tenants!inner(slug), events(name, cover_image_path, venues(name)), campaign_products(*)')
        .eq('slug', campaignSlug)
        .eq('tenants.slug', tenantSlug)
        .eq('status', 'published')
        .isFilter('deleted_at', null)
        .single();
    return PublicCampaign.fromMap(row);
  }

  Future<Map<String, dynamic>> createPublicOrder({
    required String campaignId,
    required String name,
    required String email,
    required String phone,
    required Map<String, int> products,
    Map<String, int> catalogProducts = const <String, int>{},
    required String idempotencyKey,
  }) async {
    final response = await _client.functions.invoke('create-public-order', body: {
      'campaign_id': campaignId,
      'customer_name': name.trim(),
      'customer_email': email.trim().toLowerCase(),
      'customer_phone': phone.trim(),
      'products': products,
      'catalog_products': catalogProducts,
      'idempotency_key': idempotencyKey,
    });
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida do checkout.');
    }
    if (data['error'] != null) {
      throw Exception(data['error'] is Map ? data['error']['message'] : data['error']);
    }
    return data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;
  }
}