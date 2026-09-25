// Changelog:
// 2026-09-19: P9 (Trilha F) — status da transação no detalhe do pedido agora
// usa os mesmos rótulos em português de payments_page.dart (approved →
// Aprovado, rejected → Recusado, cancelled → Cancelado, refunded → Estornado,
// demais → Pendente). Nenhuma outra mudança.
// 2026-09-18: Item 10 (Orders) — detalhe do pedido passa a exibir a(s)
// transação(ões) vinculada(s) (provider, status, valor), usando
// order.transactions (novo campo em SambaOrder). Status da transação exibido
// bruto (sem tradução) porque o enum de payment_transactions.status não foi
// confirmado no banco — evita rótulo inventado.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/order.dart';
import 'orders_controller.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({required this.tenantId, super.key});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersControllerProvider(tenantId));
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
            onRetry: () => ref
                .read(ordersControllerProvider(tenantId).notifier)
                .refresh()),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(ordersControllerProvider(tenantId).notifier)
                    .refresh(),
                child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, index) => _OrderTile(order: items[index])),
              ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final SambaOrder order;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return AppCard(
      onTap: () => _showDetails(context),
      semanticLabel: 'Abrir pedido de ${order.customerName}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(order.customerName,
                  style: AppTypography.textTheme.titleMedium)),
          _StatusChip(label: _statusLabel(order.status), color: color)
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text(order.customerEmail, style: AppTypography.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${order.items.length} item(ns)',
              style: AppTypography.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted)),
          Text('R\$ ${order.grossAmount.replaceAll('.', ',')}',
              style: AppTypography.textTheme.titleMedium
                  ?.copyWith(color: AppColors.wine))
        ]),
      ]),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detalhes do pedido',
                          style: AppTypography.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.md),
                      Text('Cliente: ${order.customerName}'),
                      Text('E-mail: ${order.customerEmail}'),
                      Text('Telefone: ${order.customerPhone}'),
                      const SizedBox(height: AppSpacing.md),
                      ...order.items.map((item) => Text(
                          '${item.quantity}× ${item.productName} — R\$ ${item.totalPrice.replaceAll('.', ',')}')),
                      if (order.transactions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Transação',
                            style: AppTypography.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        ...order.transactions.map((tx) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Text(
                                '${tx.provider} — ${_paymentStatusLabel(tx.status)} — R\$ ${tx.amount.replaceAll('.', ',')}'))),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text('Criado em ${_date(order.createdAt)}',
                          style: AppTypography.textTheme.bodySmall)
                    ]))));
  }

  Color _statusColor(String status) => switch (status) {
        'paid' => AppColors.success,
        'cancelled' || 'refunded' || 'failed' => AppColors.error,
        _ => AppColors.orange
      };
  String _statusLabel(String status) => switch (status) {
        'paid' => 'Pago',
        'cancelled' => 'Cancelado',
        'refunded' => 'Reembolsado',
        'failed' => 'Falhou',
        _ => 'Pendente'
      };
  // Mesmos rótulos de payments_page.dart (status de payment_transactions).
  String _paymentStatusLabel(String status) => switch (status) {
        'approved' => 'Aprovado',
        'rejected' => 'Recusado',
        'cancelled' => 'Cancelado',
        'refunded' => 'Estornado',
        _ => 'Pendente'
      };
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: AppTypography.textTheme.labelSmall?.copyWith(color: color)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text('Ainda não há pedidos para esta organização.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: TextButton(
          onPressed: onRetry, child: const Text('Tentar novamente')));
}