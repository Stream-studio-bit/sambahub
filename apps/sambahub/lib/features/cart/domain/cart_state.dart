// lib/features/cart/domain/cart_state.dart
//
// CHANGELOG
// 2026-09-22: Unificação de carrinho (campanha + catálogo).
// - add() deixou de receber CampaignProduct e passa a receber CartProductRef
//   (campanha ou catálogo) — construído pelo chamador via
//   CartProductRef.fromCampaignProduct/.fromCatalogProduct antes de chamar.
// - A chave do map `items` deixou de ser `product.id` cru e passou a ser
//   `product.cartKey` ('campaign:<id>' ou 'catalog:<id>'), exposto por
//   CartProductRef. Isso evita colisão entre um CampaignProduct e um
//   CatalogProduct que compartilhem o mesmo UUID, já que vêm de tabelas
//   diferentes (campaign_products x catálogo) — mesma garantia que os
//   antigos _cart/_catalogCart separados davam em public_campaign_page.dart.
// - remove()/setQuantity() continuam recebendo uma String como identificador
//   de linha do carrinho (parâmetro renomeado de `productId` para `cartKey`
//   só para deixar explícito) — quem chama precisa passar item.product.cartKey,
//   não mais o id cru. Nenhuma lógica interna desses dois métodos mudou além
//   do nome do parâmetro: eles já operavam sobre a chave do map, não sobre
//   product.id diretamente.
// - Import de public_campaign.dart saiu (CampaignProduct não é mais
//   referenciado aqui); entram cart_item.dart (que já exporta
//   CartProductRef) — catalog_product.dart não precisa de import direto
//   neste arquivo pois CartState só enxerga CartProductRef, nunca
//   CampaignProduct/CatalogProduct crus.

import 'cart_item.dart';

class CartState {
  const CartState({this.items = const {}});

  final Map<String, CartItem> items;

  bool get isEmpty => items.isEmpty;
  int get totalQuantity =>
      items.values.fold(0, (sum, item) => sum + item.quantity);
  int get totalCents =>
      items.values.fold(0, (sum, item) => sum + item.totalCents);

  CartState add(CartProductRef product, {int quantity = 1}) {
    if (quantity <= 0) return this;
    final cartKey = product.cartKey;
    final current = items[cartKey];
    final nextQuantity = (current?.quantity ?? 0) + quantity;
    final limitedQuantity = product.stockQuantity == null
        ? nextQuantity
        : nextQuantity.clamp(0, product.stockQuantity!).toInt();
    return CartState(
      items: {
        ...items,
        cartKey: CartItem(product: product, quantity: limitedQuantity),
      },
    );
  }

  CartState remove(String cartKey, {int quantity = 1}) {
    final current = items[cartKey];
    if (current == null || quantity <= 0) return this;
    final nextQuantity = current.quantity - quantity;
    final nextItems = {...items};
    if (nextQuantity <= 0) {
      nextItems.remove(cartKey);
    } else {
      nextItems[cartKey] = current.copyWith(quantity: nextQuantity);
    }
    return CartState(items: nextItems);
  }

  CartState setQuantity(String cartKey, int quantity) {
    final current = items[cartKey];
    if (current == null) return this;
    if (quantity <= 0) return remove(cartKey, quantity: current.quantity);
    final max = current.product.stockQuantity;
    final safeQuantity =
        max == null ? quantity : quantity.clamp(0, max).toInt();
    return CartState(
        items: {...items, cartKey: current.copyWith(quantity: safeQuantity)});
  }

  CartState clear() => const CartState();
}