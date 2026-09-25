// lib/features/cart/domain/cart_item.dart
//
// CHANGELOG
// 2026-09-22: Unificação de carrinho (campanha + catálogo). CartItem.product
// deixou de ser CampaignProduct fixo — agora é CartProductRef, um tipo
// intermediário que representa tanto um CampaignProduct (ingresso/produto de
// campanha) quanto um CatalogProduct (item de cardápio), com preço já
// normalizado em centavos nos dois casos. Motivo: CampaignProduct.price é
// String parseada e CatalogProduct.priceCents já é int nativo — unificar sem
// esse wrapper obrigaria a duplicar parse ou forçar um tipo no outro.
// CartProductRef.cartKey ('campaign:<id>' ou 'catalog:<id>') existe porque
// campaign_products e o catálogo são tabelas diferentes — dois produtos de
// tabelas diferentes podem ter o mesmo id (ambos UUID), e o código anterior
// (public_campaign_page.dart, carrinhos _cart/_catalogCart separados)
// evitava essa colisão deliberadamente. CartState (próximo arquivo) usa
// cartKey em vez de product.id cru para manter essa garantia dentro de um
// único Map.
// _parseCampaignPriceCents é a mesma lógica que já existia em
// CartItem._parseCents, só movida para CartProductRef.fromCampaignProduct
// (agora é o único lugar que faz parse de preço em String — catálogo nunca
// precisou disso).
// Não altera CampaignProduct nem CatalogProduct — só consome.

import '../../campaigns/domain/public_campaign.dart';
import '../../catalog/domain/catalog_product.dart';

enum CartProductSource { campaign, catalog }

/// Representação unificada de um produto dentro do carrinho, independente
/// de vir de campaign_products (ingressos/campanha) ou do catálogo
/// (cardápio). Preço sempre em centavos.
class CartProductRef {
  const CartProductRef({
    required this.source,
    required this.id,
    required this.name,
    required this.unitPriceCents,
    this.stockQuantity,
    this.isActive = true,
  });

  final CartProductSource source;
  final String id;
  final String name;
  final int unitPriceCents;
  final int? stockQuantity;
  final bool isActive;

  /// Chave estável e sem colisão entre as duas origens — usar sempre esta
  /// chave (nunca `id` sozinho) para indexar o carrinho em CartState.
  String get cartKey => '${source.name}:$id';

  factory CartProductRef.fromCampaignProduct(CampaignProduct product) {
    return CartProductRef(
      source: CartProductSource.campaign,
      id: product.id,
      name: product.name,
      unitPriceCents: _parseCampaignPriceCents(product.price),
      stockQuantity: product.stockQuantity,
      isActive: product.isActive,
    );
  }

  factory CartProductRef.fromCatalogProduct(CatalogProduct product) {
    return CartProductRef(
      source: CartProductSource.catalog,
      id: product.id,
      name: product.name,
      unitPriceCents: product.priceCents,
      stockQuantity: product.stockQuantity,
      isActive: product.isActive,
    );
  }

  static int _parseCampaignPriceCents(String value) {
    final raw = value.trim().replaceAll('R\$', '').trim();
    final normalized =
        raw.contains(',') ? raw.replaceAll('.', '').replaceAll(',', '.') : raw;
    final parts = normalized.split('.');
    final reais =
        int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
    final decimals =
        parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '0';
    final centavos =
        int.tryParse(decimals.padRight(2, '0').substring(0, 2)) ?? 0;
    return (reais * 100) + centavos;
  }
}

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final CartProductRef product;
  final int quantity;

  int get unitPriceCents => product.unitPriceCents;
  int get totalCents => unitPriceCents * quantity;

  CartItem copyWith({CartProductRef? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}