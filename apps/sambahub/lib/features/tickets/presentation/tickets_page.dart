// Changelog:
// 2026-09-18: Item 7 (Tickets) — adicionado filtro 'refunded' (status válido
// confirmado em supabase/migrations/20260915000013_create_tickets.sql, check
// constraint tickets_status_check). Repository, controller e model
// permanecem inalterados: já cobriam consulta, detalhes e refresh; nenhum
// mecanismo de identificação/código de ticket foi tocado.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/ticket.dart';
import 'tickets_controller.dart';

class TicketsPage extends ConsumerStatefulWidget {
  const TicketsPage({required this.tenantId, super.key, this.eventId});
  final String tenantId;
  final String? eventId;
  @override
  ConsumerState<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends ConsumerState<TicketsPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final query =
        TicketQuery(tenantId: widget.tenantId, eventId: widget.eventId);
    final tickets = ref.watch(ticketsControllerProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Ingressos')),
      body: tickets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
            onRetry: () =>
                ref.read(ticketsControllerProvider(query).notifier).refresh()),
        data: (items) {
          final visible = _filter == 'all'
              ? items
              : items
                  .where((ticket) => ticket.status == _filter)
                  .toList(growable: false);
          if (items.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(ticketsControllerProvider(query).notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        children: [
                          'all',
                          'issued',
                          'used',
                          'cancelled',
                          'refunded'
                        ]
                            .map((filter) => Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.xs),
                                child: ChoiceChip(
                                    label: Text(_label(filter)),
                                    selected: _filter == filter,
                                    onSelected: (_) =>
                                        setState(() => _filter = filter))))
                            .toList())),
                const SizedBox(height: AppSpacing.md),
                if (visible.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child:
                          Center(child: Text('Nenhum ingresso neste filtro.'))),
                ...visible.map((ticket) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TicketTile(ticket: ticket))),
              ],
            ),
          );
        },
      ),
    );
  }

  String _label(String status) => switch (status) {
        'all' => 'Todos',
        'issued' => 'Emitidos',
        'used' => 'Utilizados',
        'cancelled' => 'Cancelados',
        'refunded' => 'Reembolsados',
        _ => status
      };
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final SambaTicket ticket;
  @override
  Widget build(BuildContext context) {
    final color = ticket.isValid
        ? AppColors.success
        : ticket.isUsed
            ? AppColors.orange
            : AppColors.error;
    return AppCard(
        onTap: () => _showDetails(context),
        semanticLabel: 'Abrir ingresso de ${ticket.holderName}',
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  ticket.isValid
                      ? Icons.confirmation_number_outlined
                      : ticket.isUsed
                          ? Icons.verified_rounded
                          : Icons.block_rounded,
                  color: color)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(ticket.holderName,
                    style: AppTypography.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(ticket.productName ?? 'Ingresso',
                    style: AppTypography.textTheme.bodySmall),
                Text(ticket.code,
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted))
              ])),
          Text(_label(ticket.status),
              style: AppTypography.textTheme.labelSmall?.copyWith(color: color))
        ]));
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
                      Text('Detalhes do ingresso',
                          style: AppTypography.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.md),
                      Text('Titular: ${ticket.holderName}'),
                      Text('E-mail: ${ticket.holderEmail}'),
                      Text('Código: ${ticket.code}'),
                      Text('Evento: ${ticket.eventName ?? '—'}'),
                      Text('Status: ${_label(ticket.status)}'),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Emitido em ${_date(ticket.issuedAt)}',
                          style: AppTypography.textTheme.bodySmall)
                    ]))));
  }

  String _label(String status) => switch (status) {
        'issued' => 'Emitido',
        'used' => 'Utilizado',
        'cancelled' => 'Cancelado',
        'refunded' => 'Reembolsado',
        _ => status
      };
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text('Ainda não há ingressos emitidos.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.md),
        const Text('Não foi possível carregar os ingressos.'),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente'))
      ]));
}