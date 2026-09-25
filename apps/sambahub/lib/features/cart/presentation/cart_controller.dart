// lib/features/cart/presentation/cart_controller.dart
//
// CHANGELOG
// 2026-09-22: Unificação de carrinho (campanha + catálogo).
// - add() deixou de aceitar CampaignProduct e passa a aceitar CartProductRef,
//   acompanhando a mudança de assinatura em CartState.add() (cart_state.dart).
//   Nenhuma lógica interna mudou — apenas repassa para state.add().
// - remove()/setQuantity() não mudaram de assinatura: já recebiam String
//   (agora entendida como cartKey, não mais productId cru) e só repassam
//   para CartState, que é quem trata a chave composta.
// - Import de public_campaign.dart saiu (CampaignProduct não é mais
//   referenciado aqui); entra cart_item.dart, que exporta CartProductRef.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cart_item.dart';
import '../domain/cart_state.dart';

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(CartProductRef product, {int quantity = 1}) {
    state = state.add(product, quantity: quantity);
  }

  void remove(String productId, {int quantity = 1}) {
    state = state.remove(productId, quantity: quantity);
  }

  void setQuantity(String productId, int quantity) {
    state = state.setQuantity(productId, quantity);
  }

  void clear() {
    state = state.clear();
  }
}