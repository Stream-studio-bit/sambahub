// lib/features/cart/presentation/cart_page.dart
//
// CHANGELOG
// 2026-09-22: Unificação de carrinho (campanha + catálogo).
// - Nenhuma mudança estrutural necessária: item.product.name e
//   item.totalCents continuam existindo em CartProductRef exatamente como
//   antes em CampaignProduct, então o layout e o restante do arquivo
//   permanecem intactos.
// - Correção pontual em _CartItemTile: o botão "-" chamava
//   controller.remove(item.product.id), usando o id cru do produto. Como
//   CartState/CartController agora indexam o carrinho por
//   `product.cartKey` ('campaign:<id>' ou 'catalog:<id>'), passar o id cru
//   não dá erro de compilação (o tipo continua String) mas falha em
//   runtime: a chave não é encontrada no map, `remove()` retorna o estado
//   inalterado, e o botão "-" fica mudo, sem exceção nem log. Corrigido
//   para controller.remove(item.product.cartKey). O botão "+" já estava
//   correto, pois controller.add(item.product) repassa o CartProductRef
//   inteiro e é o próprio CartState.add() que resolve a cartKey
//   internamente.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/cart_item.dart';
import 'cart_controller.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key, this.onCheckout});

  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu carrinho'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Limpar carrinho',
              onPressed: controller.clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const _EmptyCart()
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                  AppSpacing.md, AppSpacing.section),
              children: [
                ...cart.items.values.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _CartItemTile(item: item),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    children: [
                      _SummaryLine(
                          label: 'Itens', value: '${cart.totalQuantity}'),
                      const SizedBox(height: AppSpacing.sm),
                      _SummaryLine(
                          label: 'Total',
                          value: _formatCents(cart.totalCents),
                          emphasized: true),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Continuar para checkout',
                        isFullWidth: true,
                        onPressed: onCheckout,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static String _formatCents(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartControllerProvider.notifier);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: AppTypography.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(CartPage._formatCents(item.totalCents),
                    style: AppTypography.textTheme.titleSmall
                        ?.copyWith(color: AppColors.wine)),
              ],
            ),
          ),
          IconButton(
              onPressed: () => controller.remove(item.product.cartKey),
              icon: const Icon(Icons.remove_circle_outline)),
          Text('${item.quantity}', style: AppTypography.textTheme.titleMedium),
          IconButton(
              onPressed: () => controller.add(item.product),
              icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(
      {required this.label, required this.value, this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: emphasized
                ? AppTypography.textTheme.titleMedium
                : AppTypography.textTheme.bodyMedium),
        Text(value,
            style: emphasized
                ? AppTypography.textTheme.titleLarge
                    ?.copyWith(color: AppColors.wine)
                : AppTypography.textTheme.bodyMedium)
      ]);
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shopping_bag_outlined,
                size: 56, color: AppColors.wine),
            const SizedBox(height: AppSpacing.lg),
            Text('Seu carrinho está vazio',
                style: AppTypography.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text('Escolha seus ingressos para começar.',
                style: AppTypography.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted))
          ])));
}