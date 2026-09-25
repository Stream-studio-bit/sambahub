import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'brand_mark.dart';

class SambaHero extends StatelessWidget {
  const SambaHero({
    required this.title,
    super.key,
    this.subtitle,
    this.imageUrl,
    this.eyebrow = 'Roda de samba',
    this.child,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String eyebrow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 360),
      decoration: BoxDecoration(
        color: AppColors.wineDeep,
        image: imageUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(
                  AppColors.heroOverlay,
                  BlendMode.darken,
                ),
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.section,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const BrandMark(light: true),
              const Spacer(),
              Text(
                eyebrow.toUpperCase(),
                style: AppTypography.textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.textTheme.displaySmall?.copyWith(
                  color: AppColors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle!,
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    color: AppColors.darkMuted,
                  ),
                ),
              ],
              if (child != null) ...[
                const SizedBox(height: AppSpacing.lg),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
