import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class QuantityControlView extends StatelessWidget {
  const QuantityControlView({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    super.key,
    this.enabled = true,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.touchTarget,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed: enabled ? onDecrease : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: AppColors.wine,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed: enabled ? onIncrease : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            color: AppColors.wine,
          ),
        ],
      ),
    );
  }
}
