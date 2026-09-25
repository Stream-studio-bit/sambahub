// CHANGELOG
// 2026-09-19 — P5 / Trilha C (Relatórios)
// - Seletor de período implementado (Este mês, Mês passado, Últimos 7 dias,
//   Últimos 30 dias e Personalizado com showDateRangePicker). O período fica
//   em estado do widget, por isso a página virou ConsumerStatefulWidget.
// - Corrigido o recarregamento infinito: a ReportQuery era montada no build
//   com DateTime.now(), então cada rebuild gerava uma chave de família nova e
//   um RPC novo. Agora usa ReportQuery.period, que normaliza por dia.
// - Estado vazio: período sem pedidos, ingressos e eventos mostra aviso em vez
//   de uma tela de zeros.
// - Erro: exibe a mensagem real (ReportsException.message) e mantém o botão
//   "Tentar novamente"; o seletor de período continua acessível no erro e no
//   loading, para o usuário trocar de período sem sair da tela.
// - Dinheiro: formatação própria com separador de milhar e sempre 2 casas. O
//   replaceAll('.', ',') anterior mostrava "R$ 1234,5" quando o banco devolvia
//   1234.5 e não separava milhar. Valores continuam vindo como string decimal
//   da numeric(12,2); nada é convertido para centavos aqui.
// - Conversão e check-in mostram também a contagem absoluta (N de M). Divisão
//   por zero já é tratada no domain (ReportSummary).
// - Nenhum campo novo, nenhuma chamada nova ao banco.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../data/reports_repository.dart';
import '../domain/report_summary.dart';
import 'reports_controller.dart';

enum _PeriodPreset {
  thisMonth('Este mês'),
  lastMonth('Mês passado'),
  last7('Últimos 7 dias'),
  last30('Últimos 30 dias'),
  custom('Personalizado');

  const _PeriodPreset(this.label);
  final String label;
}

class _Period {
  const _Period(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({required this.tenantId, super.key});

  final String tenantId;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  _PeriodPreset _preset = _PeriodPreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  _Period _resolvePeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case _PeriodPreset.thisMonth:
        return _Period(DateTime(now.year, now.month, 1), today);
      case _PeriodPreset.lastMonth:
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final lastDayPrevious =
            firstOfThisMonth.subtract(const Duration(days: 1));
        return _Period(
          DateTime(lastDayPrevious.year, lastDayPrevious.month, 1),
          lastDayPrevious,
        );
      case _PeriodPreset.last7:
        return _Period(today.subtract(const Duration(days: 6)), today);
      case _PeriodPreset.last30:
        return _Period(today.subtract(const Duration(days: 29)), today);
      case _PeriodPreset.custom:
        final start = _customStart ?? DateTime(now.year, now.month, 1);
        final end = _customEnd ?? today;
        return _Period(start, end);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final current = _resolvePeriod();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: current.start,
        end: current.end.isAfter(now) ? now : current.end,
      ),
      helpText: 'Selecione o período',
      saveText: 'Aplicar',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (range == null || !mounted) {
      return;
    }
    setState(() {
      _preset = _PeriodPreset.custom;
      _customStart = range.start;
      _customEnd = range.end;
    });
  }

  void _selectPreset(_PeriodPreset preset) {
    if (preset == _PeriodPreset.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _preset = preset);
  }

  @override
  Widget build(BuildContext context) {
    final period = _resolvePeriod();
    final query = ReportQuery.period(
      tenantId: widget.tenantId,
      start: period.start,
      end: period.end,
    );
    final report = ref.watch(reportsControllerProvider(query));
    Future<void> reload() =>
        ref.read(reportsControllerProvider(query).notifier).refresh();

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: Column(
        children: [
          _PeriodSelector(
            selected: _preset,
            start: query.periodStart,
            end: query.periodEnd,
            onSelected: _selectPreset,
          ),
          Expanded(
            child: report.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error is ReportsException
                    ? error.message
                    : 'Não foi possível carregar o relatório.',
                onRetry: reload,
              ),
              data: (summary) => RefreshIndicator(
                onRefresh: reload,
                child: _isEmpty(summary)
                    ? _EmptyState(onRetry: reload)
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _MetricGrid(summary: summary),
                          const SizedBox(height: AppSpacing.md),
                          _RevenueCard(summary: summary),
                          const SizedBox(height: AppSpacing.md),
                          _ConversionCard(summary: summary),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isEmpty(ReportSummary summary) =>
      summary.ordersCount == 0 &&
      summary.ticketsIssued == 0 &&
      summary.eventsCount == 0;
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.start,
    required this.end,
    required this.onSelected,
  });

  final _PeriodPreset selected;
  final DateTime start;
  final DateTime end;
  final ValueChanged<_PeriodPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: _PeriodPreset.values
                .map(
                  (preset) => ChoiceChip(
                    label: Text(preset.label),
                    selected: preset == selected,
                    onSelected: (_) => onSelected(preset),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Período ${_formatDate(start)} — ${_formatDate(end)}',
            style: AppTypography.textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (_, constraints) {
        final columns = constraints.maxWidth > 650 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.35,
          children: [
            _metric('Eventos', '${summary.eventsCount}', Icons.event_outlined),
            _metric(
              'Pedidos pagos',
              '${summary.paidOrdersCount}',
              Icons.shopping_bag_outlined,
            ),
            _metric(
              'Ingressos',
              '${summary.ticketsIssued}',
              Icons.confirmation_number_outlined,
            ),
            _metric(
              'Check-ins',
              '${summary.ticketsCheckedIn}',
              Icons.qr_code_scanner_rounded,
            ),
          ],
        );
      });

  Widget _metric(String label, String value, IconData icon) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppColors.wine),
            Text(value, style: AppTypography.textTheme.headlineSmall),
            Text(
              label,
              style: AppTypography.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      );
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receita', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _line('Bruta', summary.grossRevenue),
            _line('Taxas da plataforma', summary.platformFees),
            _line('Reembolsos', summary.refundedAmount),
            const Divider(height: AppSpacing.lg),
            _line('Líquida', summary.netRevenue, emphasized: true),
          ],
        ),
      );

  Widget _line(String label, String value, {bool emphasized = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: emphasized ? AppTypography.textTheme.titleMedium : null,
            ),
            Text(
              _formatMoney(value),
              style: emphasized
                  ? AppTypography.textTheme.titleMedium
                      ?.copyWith(color: AppColors.wine)
                  : null,
            ),
          ],
        ),
      );
}

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operação', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _progress(
              'Conversão de pagamento',
              summary.paymentConversionRate,
              '${summary.paidOrdersCount} de ${summary.ordersCount} pedidos pagos',
            ),
            _progress(
              'Check-in dos ingressos',
              summary.checkinRate,
              '${summary.ticketsCheckedIn} de ${summary.ticketsIssued} ingressos utilizados',
            ),
          ],
        ),
      );

  Widget _progress(String label, double value, String detail) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label),
                Text('${(value * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: value.clamp(0, 1).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.orange,
              backgroundColor: AppColors.peach,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              style: AppTypography.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Column(
              children: [
                const Icon(
                  Icons.insights_outlined,
                  size: 48,
                  color: AppColors.muted,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Sem movimentação neste período.',
                  style: AppTypography.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Escolha outro período acima ou atualize para tentar de novo.',
                  style: AppTypography.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Atualizar'),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Os valores chegam como string decimal da numeric(12,2) ('1234.50').
/// Sem dependência nova: formata em pt-BR com separador de milhar.
String _formatMoney(String raw) {
  final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
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
  return '$sign R\$ $buffer,$decimals'.trim();
}