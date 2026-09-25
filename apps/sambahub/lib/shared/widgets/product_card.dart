// CHANGELOG
// 2026-09-22: Correção pós-unificação de carrinho (campanha + catálogo).
// cartControllerProvider.add() passou a exigir CartProductRef (ver
// cart_item.dart/cart_controller.dart), não mais CampaignProduct direto, e
// CartState.items passou a ser indexado por cartKey ('campaign:<id>' /
// 'catalog:<id>'), não pelo id cru. Isso quebrou 2 pontos aqui:
// - ProductCard.build() e QuantityControl.build() chamavam
//   controller.add(product) passando CampaignProduct — dart analyze acusava
//   argument_type_not_assignable. Agora ambos constroem
//   CartProductRef.fromCampaignProduct(product) uma vez e passam a
//   referência para add().
// - Os dois liam/escreviam o carrinho por product.id cru
//   (cart.items[product.id], controller.remove(product.id)) — compilava
//   (String é String), mas é a mesma colisão de chave que a unificação foi
//   feita pra evitar (campaign_products e catálogo podem repetir id).
//   Trocado para cartRef.cartKey nos dois lugares.
// Nenhuma outra lógica alterada.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../features/campaigns/domain/public_campaign.dart';
import '../../features/cart/domain/cart_item.dart';
import '../../features/cart/presentation/cart_controller.dart';
import 'quantity_control.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({required this.product, super.key});

  final CampaignProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final cartRef = CartProductRef.fromCampaignProduct(product);
    final quantity = cart.items[cartRef.cartKey]?.quantity ?? 0;
    return AppCard(
      semanticLabel: 'Produto ${product.name}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.confirmation_number_outlined,
                color: AppColors.wine),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTypography.textTheme.titleMedium),
                if (product.description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(product.description!,
                      style: AppTypography.textTheme.bodySmall),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text('R\$ ${product.price.replaceAll('.', ',')}',
                    style: AppTypography.textTheme.titleMedium
                        ?.copyWith(color: AppColors.wine)),
                const SizedBox(height: AppSpacing.sm),
                if (quantity == 0)
                  AppButton(
                      label: 'Adicionar',
                      size: AppButtonSize.small,
                      onPressed: product.isActive
                          ? () => ref
                              .read(cartControllerProvider.notifier)
                              .add(cartRef)
                          : null)
                else
                  QuantityControl(product: product),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuantityControl extends ConsumerWidget {
  const QuantityControl({required this.product, super.key});
  final CampaignProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartRef = CartProductRef.fromCampaignProduct(product);
    final quantity =
        ref.watch(cartControllerProvider).items[cartRef.cartKey]?.quantity ??
            0;
    final controller = ref.read(cartControllerProvider.notifier);
    return QuantityControlView(
      quantity: quantity,
      onDecrease: () => controller.remove(cartRef.cartKey),
      onIncrease: () => controller.add(cartRef),
    );
  }
}