import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/cart/presentation/cart_controller.dart';
import 'checkout_drawer.dart';

class CartDock extends ConsumerWidget {
  const CartDock({super.key, this.onCheckout});

  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: Material(
        color: AppColors.wineDeep,
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onCheckout ?? () => CheckoutDrawer.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${cart.totalQuantity}',
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Seu carrinho',
                    style: AppTypography.textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
                Text(
                  'R\$ ${_formatCents(cart.totalCents)}',
                  style: AppTypography.textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCents(int cents) {
    final absolute = cents.abs();
    final reais = absolute ~/ 100;
    final centavos = (absolute % 100).toString().padLeft(2, '0');
    return '${cents < 0 ? '-' : ''}$reais,$centavos';
  }
}
