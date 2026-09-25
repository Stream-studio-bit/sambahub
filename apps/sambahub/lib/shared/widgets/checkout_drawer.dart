import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../features/cart/presentation/cart_controller.dart';
import 'quantity_control.dart';

class CheckoutDrawer extends ConsumerWidget {
  const CheckoutDrawer({super.key, this.onContinue});
  final VoidCallback? onContinue;

  static Future<void> show(BuildContext context, {VoidCallback? onContinue}) {
    return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.paper,
        builder: (_) => CheckoutDrawer(onContinue: onContinue));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seu pedido', style: AppTypography.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              if (cart.isEmpty)
                const Text('Seu carrinho está vazio.')
              else
                ...cart.items.values.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.product.name,
                                style: AppTypography.textTheme.titleMedium),
                            Text('R\$ ${_formatCents(item.product.unitPriceCents)}',
                                style: AppTypography.textTheme.bodySmall)
                          ])),
                      QuantityControlView(
                          quantity: item.quantity,
                          onDecrease: () => ref
                              .read(cartControllerProvider.notifier)
                              .remove(item.product.cartKey),
                          onIncrease: () => ref
                              .read(cartControllerProvider.notifier)
                              .add(item.product))
                    ]))),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total', style: AppTypography.textTheme.titleMedium),
                Text('R\$ ${_formatCents(cart.totalCents)}',
                    style: AppTypography.textTheme.titleLarge
                        ?.copyWith(color: AppColors.wine))
              ]),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                  label: 'Continuar para pagamento',
                  isFullWidth: true,
                  onPressed: cart.isEmpty
                      ? null
                      : (onContinue ?? () => Navigator.of(context).pop())),
            ]),
      ),
    );
  }

  String _formatCents(int cents) =>
      '${cents < 0 ? '-' : ''}${cents.abs() ~/ 100},${(cents.abs() % 100).toString().padLeft(2, '0')}';
}