import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/tenant.dart';
import 'tenant_controller.dart';

class TenantSwitcherPage extends ConsumerWidget {
  const TenantSwitcherPage({super.key, this.onSelected});

  final ValueChanged<Tenant>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(tenantControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Escolha sua organização')),
      body: tenants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.read(tenantControllerProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(tenantControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _TenantTile(
                tenant: items[index],
                onTap: () => _select(context, items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _select(BuildContext context, Tenant tenant) {
    onSelected?.call(tenant);
    if (onSelected == null && context.mounted)
      Navigator.of(context).pop(tenant);
  }
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({required this.tenant, required this.onTap});

  final Tenant tenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Selecionar ${tenant.name}',
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.peach,
            foregroundColor: AppColors.wine,
            child: Text(tenant.name.characters.first.toUpperCase()),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenant.name, style: AppTypography.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  '${tenant.role} · ${tenant.slug}',
                  style: AppTypography.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.domain_disabled_outlined,
                size: 52, color: AppColors.wine),
            const SizedBox(height: AppSpacing.lg),
            Text('Nenhuma organização encontrada',
                style: AppTypography.textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text('Peça um convite ao administrador da sua casa ou produtora.',
                style: AppTypography.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text('Não foi possível carregar suas organizações.',
                style: AppTypography.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Tentar novamente', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
