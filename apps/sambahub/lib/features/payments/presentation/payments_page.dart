import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/payment_transaction.dart';
import 'payments_controller.dart';

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({required this.tenantId, super.key});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsControllerProvider(tenantId));
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos')),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
            onRetry: () => ref
                .read(paymentsControllerProvider(tenantId).notifier)
                .refresh()),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(paymentsControllerProvider(tenantId).notifier)
                    .refresh(),
                child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, index) =>
                        _PaymentTile(transaction: items[index])),
              ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.transaction});
  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(transaction.status);
    final shortOrderId = transaction.orderId.length > 8
        ? transaction.orderId.substring(0, 8)
        : transaction.orderId;
    return AppCard(
      onTap: () => _showDetails(context),
      semanticLabel: 'Abrir pagamento do pedido ${transaction.orderId}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Pedido $shortOrderId',
                  style: AppTypography.textTheme.titleMedium)),
          _StatusChip(label: _statusLabel(transaction.status), color: color)
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(transaction.provider.toUpperCase(),
              style: AppTypography.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted)),
          Text('R\$ ${transaction.amount.replaceAll('.', ',')}',
              style: AppTypography.textTheme.titleLarge
                  ?.copyWith(color: AppColors.wine))
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text('Criado em ${_date(transaction.createdAt)}',
            style: AppTypography.textTheme.bodySmall),
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
                      Text('Detalhes do pagamento',
                          style: AppTypography.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.md),
                      Text('Pedido: ${transaction.orderId}'),
                      Text('Provedor: ${transaction.provider}'),
                      Text('Status: ${_statusLabel(transaction.status)}'),
                      Text(
                          'Taxa: R\$ ${transaction.paymentFee.replaceAll('.', ',')}'),
                      if (transaction.providerTransactionId != null)
                        Text(
                            'Transação externa: ${transaction.providerTransactionId}'),
                      if (transaction.lastWebhookAt != null)
                        Text(
                            'Último webhook: ${_date(transaction.lastWebhookAt!)}'),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                          'O status é atualizado exclusivamente pelo webhook verificado do provedor.',
                          style: AppTypography.textTheme.bodySmall)
                    ]))));
  }

  Color _statusColor(String status) => switch (status) {
        'approved' => AppColors.success,
        'rejected' || 'cancelled' || 'refunded' => AppColors.error,
        _ => AppColors.orange
      };
  String _statusLabel(String status) => switch (status) {
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
          child: Text('Ainda não há transações de pagamento.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: TextButton(
          onPressed: onRetry, child: const Text('Tentar novamente')));
}
