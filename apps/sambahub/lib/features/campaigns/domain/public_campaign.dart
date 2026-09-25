// CHANGELOG
// 2026-09-20: coverImagePath agora usa fallback pro flyer do evento vinculado.
// Causa raiz (confirmada via SQL): campaigns.cover_image_path é null; o flyer
// fica só em events.cover_image_path. fromMap lia apenas a coluna da campanha,
// então o _hero() sempre caía no _heroFallback(). Agora: campanha primeiro,
// senão event['cover_image_path'] (exige que CampaignsRepository.findBySlug
// inclua cover_image_path no embed events(...)). Nenhuma outra lógica alterada.
// 2026-09-20: Adicionado tenantId a PublicCampaign (map['tenant_id'], já
// retornado pelo '*' de CampaignsRepository.findBySlug — só faltava o
// parsing). Necessário para a página pública buscar o catálogo do tenant
// (CatalogRepository.fetchMenu) e resolver a URL do flyer via storage.
// Nenhuma outra lógica alterada.

class CampaignProduct {
  const CampaignProduct({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    this.description,
    this.stockQuantity,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String type;
  final String price;
  final String? description;
  final int? stockQuantity;
  final bool isActive;

  factory CampaignProduct.fromMap(Map<String, dynamic> map) {
    return CampaignProduct(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'ticket',
      price: map['price'].toString(),
      description: map['description'] as String?,
      stockQuantity: map['stock_quantity'] as int?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class PublicCampaign {
  const PublicCampaign({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    required this.status,
    this.description,
    this.coverImagePath,
    this.eventName,
    this.venueName,
    this.startsAt,
    this.products = const <CampaignProduct>[],
  });

  final String id;
  final String tenantId;
  final String name;
  final String slug;
  final String status;
  final String? description;
  final String? coverImagePath;
  final String? eventName;
  final String? venueName;
  final DateTime? startsAt;
  final List<CampaignProduct> products;

  static String? _firstNonEmpty(String? a, String? b) {
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  factory PublicCampaign.fromMap(Map<String, dynamic> map) {
    final event = map['events'] is Map<String, dynamic>
        ? map['events'] as Map<String, dynamic>
        : null;
    final venue = event?['venues'] is Map<String, dynamic>
        ? event!['venues'] as Map<String, dynamic>
        : null;
    final rawProducts = map['campaign_products'] is List<dynamic>
        ? map['campaign_products'] as List<dynamic>
        : const <dynamic>[];

    return PublicCampaign(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      status: map['status'] as String,
      description: map['description'] as String?,
      coverImagePath: _firstNonEmpty(
        map['cover_image_path'] as String?,
        event?['cover_image_path'] as String?,
      ),
      eventName: event?['name'] as String?,
      venueName: venue?['name'] as String?,
      startsAt: map['starts_at'] == null
          ? null
          : DateTime.tryParse(map['starts_at'].toString()),
      products: rawProducts
          .whereType<Map<String, dynamic>>()
          .map(CampaignProduct.fromMap)
          .toList(growable: false),
    );
  }
}