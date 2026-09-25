import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import 'venue_lockup.dart';

class LocationCard extends StatelessWidget {
  const LocationCard(
      {required this.venueName,
      super.key,
      this.address,
      this.city,
      this.onOpenMap});

  final String venueName;
  final String? address;
  final String? city;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Onde acontece', style: AppTypography.textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      VenueLockup(name: venueName, address: address, city: city),
      if (onOpenMap != null) ...[
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
            onPressed: onOpenMap,
            icon: const Icon(Icons.directions_outlined, color: AppColors.wine),
            label: const Text('Ver como chegar'))
      ]
    ]));
  }
}
