// CHANGELOG
// 2026-09-19 — P8 / Trilha C (Repasses)
// - Status corrigidos para os 5 valores que o prompt mestre define para esta
//   coluna: pending, scheduled, paid, failed, cancelled. A versão anterior
//   tratava 'processing' (que não está nessa lista) e não tinha rótulo
//   próprio para 'scheduled' — caía no `_ => 'Pendente'` genérico, então um
//   repasse agendado aparecia igual a um pendente. Não vi o CHECK constraint
//   da coluna diretamente (não confirmado); os 5 valores vêm do prompt
//   mestre, não de suposição minha.
// - `_showDetails` e `_ErrorState` passaram a mostrar a mensagem real da
//   SettlementsException (ex.: aviso de permissão) em vez de texto fixo.
// - Dinheiro: troquei `value.replaceAll('.', ',')` por formatação com
//   separador de milhar — o código anterior mostrava "R$ 1234,5" quando o
//   banco devolvia "1234.5" em vez de "1234.50", e nunca separava milhar.
// - `settlement.orderId`/`venueId` (não existiam como campos antes, ver
//   domain) exibidos no detalhe apenas como referência técnica, sem nome
//   resolvido — resolver nome de venue/pedido ficaria fora do escopo do P8
//   ("Exibir corretamente: valor bruto, taxa da plataforma, ... status,
//   scheduled_at, paid_at").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../data/settlements_repository.dart';
import '../domain/settlement.dart';
import 'settlements_controller.dart';

class SettlementsPage extends ConsumerWidget {
  const SettlementsPage({required this.tenantId, super.key});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(settlementsControllerProvider(tenantId));
    final notifier =
        ref.read(settlementsControllerProvider(tenantId).notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Repasses')),
      body: settlements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is SettlementsException
              ? error.message
              : 'Não foi possível carregar os repasses.',
          onRetry: notifier.refresh,
        ),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) =>
                      _SettlementTile(settlement: items[index]),
                ),
              ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.settlement});
  final Settlement settlement;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(settlement.status);
    return AppCard(
      onTap: () => _showDetails(context),
      semanticLabel: 'Abrir repasse ${settlement.reference}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(settlement.reference,
                  style: AppTypography.textTheme.titleMedium)),
          _StatusChip(label: _statusLabel(settlement.status), color: color)
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Líquido',
              style: AppTypography.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted)),
          Text(_formatMoney(settlement.netAmount),
              style: AppTypography.textTheme.titleLarge
                  ?.copyWith(color: AppColors.wine))
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text(
            'Bruto: ${_formatMoney(settlement.grossAmount)} · Criado em ${_date(settlement.createdAt)}',
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
                      Text('Composição do repasse',
                          style: AppTypography.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.md),
                      _line('Bruto', settlement.grossAmount),
                      _line('Taxa SambaHub', settlement.platformFee),
                      _line('Taxa de pagamento', settlement.paymentFee),
                      _line('Venue', settlement.venueAmount),
                      _line('Grupo', settlement.groupAmount),
                      _line('Líquido', settlement.netAmount, emphasized: true),
                      const SizedBox(height: AppSpacing.md),
                      Text('Status: ${_statusLabel(settlement.status)}'),
                      if (settlement.scheduledAt != null)
                        Text('Agendado para ${_date(settlement.scheduledAt!)}',
                            style: AppTypography.textTheme.bodySmall),
                      if (settlement.paidAt != null)
                        Text('Pago em ${_date(settlement.paidAt!)}',
                            style: AppTypography.textTheme.bodySmall),
                    ]))));
  }

  Widget _line(String label, String value, {bool emphasized = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: emphasized ? AppTypography.textTheme.titleMedium : null),
            Text(_formatMoney(value),
                style: emphasized
                    ? AppTypography.textTheme.titleMedium
                        ?.copyWith(color: AppColors.wine)
                    : null)
          ]));

  Color _statusColor(String status) => switch (status) {
        'paid' => AppColors.success,
        'scheduled' => AppColors.orange,
        'failed' || 'cancelled' => AppColors.error,
        _ => AppColors.muted, // pending e qualquer valor inesperado
      };

  String _statusLabel(String status) => switch (status) {
        'pending' => 'Pendente',
        'scheduled' => 'Agendado',
        'paid' => 'Pago',
        'failed' => 'Falhou',
        'cancelled' => 'Cancelado',
        _ => status,
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
          child: Text('Ainda não há repasses registrados.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ]),
      ));
}

/// Recebe "1234.5" ou "1234.50" (numeric do banco) e devolve "R$ 1.234,50".
String _formatMoney(String raw) {
  final parsed = double.tryParse(raw.trim());
  if (parsed == null) {
    return 'R\$ $raw';
  }
  final cents = (parsed.abs() * 100).round();
  final digits = (cents ~/ 100).toString();
  final decimals = (cents % 100).toString().padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final sign = parsed < 0 ? '-' : '';
  return '${sign}R\$ $buffer,$decimals';
}