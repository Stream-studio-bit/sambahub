import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class VenueLockup extends StatelessWidget {
  const VenueLockup({required this.name, super.key, this.address, this.city});

  final String name;
  final String? address;
  final String? city;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.location_on_outlined, color: AppColors.orange, size: 22),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: AppTypography.textTheme.titleSmall),
        if (address != null)
          Text(address!, style: AppTypography.textTheme.bodySmall),
        if (city != null)
          Text(city!,
              style: AppTypography.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted))
      ]))
    ]);
  }
}
