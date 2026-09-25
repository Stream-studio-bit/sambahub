import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false, this.light = false});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? AppColors.white : AppColors.wineDeep;
    return Semantics(
      label: 'SambaHub',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
            decoration: const BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: AppTypography.textTheme.titleLarge?.copyWith(
                color: AppColors.white,
                fontFamily: AppTypography.displayFamily,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Text(
              'SambaHub',
              style: AppTypography.textTheme.titleLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
