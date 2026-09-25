import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.child,
    super.key,
    this.description,
    this.icon,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(title, style: AppTypography.textTheme.titleLarge),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(description!, style: AppTypography.textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: AppSpacing.lg);
}

class SettingsDangerZone extends StatelessWidget {
  const SettingsDangerZone({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Zona administrativa',
      description: 'Ações sensíveis devem ser revisadas por um proprietário.',
      icon: Icons.warning_amber_rounded,
      child: child,
    );
  }
}
