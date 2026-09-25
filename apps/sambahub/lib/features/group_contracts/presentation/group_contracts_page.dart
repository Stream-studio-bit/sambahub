// CHANGELOG
// 2026-09-19 — P6 / Trilha D (Contratos de grupo)
// - Removidos os status 'active' e 'expired' de _statusColor/_statusLabel:
//   não existem no CHECK da coluna (só draft, signed, paid, cancelled,
//   conferido na migration). Exibi-los era enganoso — nunca vinham do banco,
//   mas se algum dia vier um valor fora do esperado agora cai no `_` (rótulo
//   genérico) em vez de mostrar "Ativo" por engano.
// - `contract.title` trocado por `contract.eventName` (a coluna title nunca
//   existiu; ver CHANGELOG do domain). Quando o join não trouxer o nome do
//   evento, mostra um texto neutro em vez de quebrar.
// - `contract.endsAt` agora é nullable: formatação trata o caso de não haver
//   data de término.
// - Implementado o que faltava do P6: criar contrato (FAB), editar (só em
//   rascunho), assinar, pagar e cancelar (todas com confirmação), com estado
//   "ocupado" por contrato (evita duplo toque) e SnackBar de sucesso/erro.
//   Formulário usa seletor de grupo/evento vindo dos novos providers do
//   controller; grupo e evento não são editáveis depois de criados (mudar a
//   identidade do contrato ficou fora do escopo desta trilha — assumido).
// - Dinheiro: campo de texto aceita vírgula ou ponto, formata para 2 casas
//   antes de enviar como string decimal (padrão numeric(12,2) do banco).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../data/group_contracts_repository.dart';
import '../domain/group_contract.dart';
import 'group_contracts_controller.dart';

class GroupContractsPage extends ConsumerStatefulWidget {
  const GroupContractsPage({required this.tenantId, super.key});
  final String tenantId;

  @override
  ConsumerState<GroupContractsPage> createState() =>
      _GroupContractsPageState();
}

class _GroupContractsPageState extends ConsumerState<GroupContractsPage> {
  String? _busyContractId;

  Future<void> _run(String contractId, Future<void> Function() action,
      {required String successMessage}) async {
    setState(() => _busyContractId = contractId);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } on GroupContractsException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível concluir a ação. Tente novamente.')));
    } finally {
      if (mounted) {
        setState(() => _busyContractId = null);
      }
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    return result ?? false;
  }

  void _openCreateForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContractFormSheet(tenantId: widget.tenantId),
    );
  }

  void _openEditForm(GroupContract contract) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContractFormSheet(
        tenantId: widget.tenantId,
        existing: contract,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contracts =
        ref.watch(groupContractsControllerProvider(widget.tenantId));
    final notifier =
        ref.read(groupContractsControllerProvider(widget.tenantId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Contratos de grupos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: const Text('Novo contrato'),
      ),
      body: contracts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(onRetry: notifier.refresh),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl * 2,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    final contract = items[index];
                    return _ContractTile(
                      contract: contract,
                      busy: _busyContractId == contract.id,
                      onTap: () => _showDetails(contract),
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _showDetails(GroupContract contract) {
    final notifier =
        ref.read(groupContractsControllerProvider(widget.tenantId).notifier);
    final busy = _busyContractId == contract.id;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detalhes do contrato',
                  style: AppTypography.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text('Evento: ${contract.eventName ?? '—'}'),
              Text('Grupo: ${contract.groupName ?? '—'}'),
              Text('Status: ${_statusLabel(contract.status)}'),
              Text('Cachê: ${_formatMoney(contract.feeAmount)}'),
              Text(
                  'Período: ${_date(contract.startsAt)} — ${_dateOrDash(contract.endsAt)}'),
              if (contract.signedAt != null)
                Text('Assinado em ${_date(contract.signedAt!)}'),
              if (contract.paidAt != null)
                Text('Pago em ${_date(contract.paidAt!)}'),
              if (contract.terms != null && contract.terms!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(contract.terms!,
                    style: AppTypography.textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (contract.canEdit)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _openEditForm(contract);
                            },
                      child: const Text('Editar'),
                    ),
                  if (contract.canSign)
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              final ok = await _confirm(
                                'Assinar contrato',
                                'Confirma a assinatura deste contrato? O status vai mudar para "Assinado".',
                              );
                              if (!ok) {
                                return;
                              }
                              await _run(
                                contract.id,
                                () => notifier.signContract(contract.id),
                                successMessage: 'Contrato assinado.',
                              );
                            },
                      child: const Text('Assinar'),
                    ),
                  if (contract.canPay)
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              final ok = await _confirm(
                                'Registrar pagamento',
                                'Confirma o pagamento deste contrato? O status vai mudar para "Pago".',
                              );
                              if (!ok) {
                                return;
                              }
                              await _run(
                                contract.id,
                                () => notifier.payContract(contract.id),
                                successMessage: 'Pagamento registrado.',
                              );
                            },
                      child: const Text('Registrar pagamento'),
                    ),
                  if (contract.canCancel)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              final ok = await _confirm(
                                'Cancelar contrato',
                                'Tem certeza que deseja cancelar este contrato? Esta ação não pode ser desfeita.',
                              );
                              if (!ok) {
                                return;
                              }
                              await _run(
                                contract.id,
                                () => notifier.cancelContract(contract.id),
                                successMessage: 'Contrato cancelado.',
                              );
                            },
                      style:
                          TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Cancelar contrato'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  const _ContractTile({
    required this.contract,
    required this.busy,
    required this.onTap,
  });

  final GroupContract contract;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(contract.status);
    return AppCard(
      onTap: busy ? null : onTap,
      semanticLabel:
          'Abrir contrato ${contract.eventName ?? contract.groupName ?? contract.id}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                contract.eventName ?? 'Evento não informado',
                style: AppTypography.textTheme.titleMedium,
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _StatusChip(label: _statusLabel(contract.status), color: color),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text(
            contract.groupName ?? 'Grupo não informado',
            style: AppTypography.textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Cachê',
                style: AppTypography.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted)),
            Text(_formatMoney(contract.feeAmount),
                style: AppTypography.textTheme.titleLarge
                    ?.copyWith(color: AppColors.wine)),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_date(contract.startsAt)} — ${_dateOrDash(contract.endsAt)}',
            style: AppTypography.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
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
          child: Text('Ainda não há contratos cadastrados.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: TextButton(
          onPressed: onRetry, child: const Text('Tentar novamente')));
}

/// Formulário de criação (existing == null) ou edição (existing != null).
/// Na edição, grupo e evento não são alteráveis.
class _ContractFormSheet extends ConsumerStatefulWidget {
  const _ContractFormSheet({required this.tenantId, this.existing});

  final String tenantId;
  final GroupContract? existing;

  @override
  ConsumerState<_ContractFormSheet> createState() =>
      _ContractFormSheetState();
}

class _ContractFormSheetState extends ConsumerState<_ContractFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _feeController = TextEditingController();
  final _termsController = TextEditingController();
  String? _groupId;
  String? _eventId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _groupId = existing.groupId;
      _eventId = existing.eventId;
      _startsAt = existing.startsAt;
      _endsAt = existing.endsAt;
      _feeController.text = _decimalToInput(existing.feeAmount);
      _termsController.text = existing.terms ?? '';
    }
  }

  @override
  void dispose() {
    _feeController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _pickStartsAt() async {
    final picked = await _pickDateTime(context, _startsAt ?? DateTime.now());
    if (picked != null) {
      setState(() => _startsAt = picked);
    }
  }

  Future<void> _pickEndsAt() async {
    final picked =
        await _pickDateTime(context, _endsAt ?? _startsAt ?? DateTime.now());
    if (picked != null) {
      setState(() => _endsAt = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_groupId == null || _eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecione o grupo e o evento do contrato.')));
      return;
    }
    if (_startsAt == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o início.')));
      return;
    }
    if (_endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('O término precisa ser depois do início.')));
      return;
    }
    final feeAmount = _parseMoneyInput(_feeController.text);
    if (feeAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe um valor de cachê válido.')));
      return;
    }

    setState(() => _saving = true);
    final notifier =
        ref.read(groupContractsControllerProvider(widget.tenantId).notifier);
    try {
      if (_isEditing) {
        await notifier.editContract(
          id: widget.existing!.id,
          feeAmount: feeAmount,
          startsAt: _startsAt!,
          endsAt: _endsAt,
          terms: _termsController.text.trim().isEmpty
              ? null
              : _termsController.text.trim(),
        );
      } else {
        await notifier.createContract(
          groupId: _groupId!,
          eventId: _eventId!,
          feeAmount: feeAmount,
          startsAt: _startsAt!,
          endsAt: _endsAt,
          terms: _termsController.text.trim().isEmpty
              ? null
              : _termsController.text.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _isEditing ? 'Contrato atualizado.' : 'Contrato criado.')));
    } on GroupContractsException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível salvar o contrato. Tente novamente.')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync =
        ref.watch(groupContractGroupOptionsProvider(widget.tenantId));
    final eventsAsync =
        ref.watch(groupContractEventOptionsProvider(widget.tenantId));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Editar contrato' : 'Novo contrato',
                  style: AppTypography.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_isEditing) ...[
                  _OptionsDropdown(
                    label: 'Grupo',
                    async: groupsAsync,
                    value: _groupId,
                    onChanged: (value) => setState(() => _groupId = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _OptionsDropdown(
                    label: 'Evento',
                    async: eventsAsync,
                    value: _eventId,
                    onChanged: (value) => setState(() => _eventId = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextFormField(
                  controller: _feeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cachê (R\$)',
                    hintText: '0,00',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe o valor do cachê.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Início'),
                  subtitle: Text(
                      _startsAt == null ? 'Selecionar' : _dateTime(_startsAt!)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickStartsAt,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Término (opcional)'),
                  subtitle: Text(
                      _endsAt == null ? 'Selecionar' : _dateTime(_endsAt!)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickEndsAt,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _termsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Termos (opcional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsDropdown extends StatelessWidget {
  const _OptionsDropdown({
    required this.label,
    required this.async,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AsyncValue<List<ContractOption>> async;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => Text('Não foi possível carregar $label.',
          style: TextStyle(color: AppColors.error)),
      data: (options) => DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((option) => DropdownMenuItem(
                  value: option.id,
                  child: Text(option.name),
                ))
            .toList(),
        onChanged: onChanged,
        validator: (selected) =>
            selected == null ? 'Selecione o $label.' : null,
      ),
    );
  }
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2023, 1, 1),
    lastDate: DateTime(2035, 12, 31),
  );
  if (date == null || !context.mounted) {
    return null;
  }
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) {
    return date;
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Color _statusColor(String status) => switch (status) {
      'signed' => AppColors.orange,
      'paid' => AppColors.success,
      'cancelled' => AppColors.error,
      _ => AppColors.muted, // draft e qualquer valor inesperado
    };

String _statusLabel(String status) => switch (status) {
      'draft' => 'Rascunho',
      'signed' => 'Assinado',
      'paid' => 'Pago',
      'cancelled' => 'Cancelado',
      _ => status,
    };

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _dateOrDash(DateTime? date) => date == null ? '—' : _date(date);

String _dateTime(DateTime date) =>
    '${_date(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// Recebe "1500.00" (numeric do banco, sempre com ponto) e devolve "1500,00"
/// para exibir no campo de texto ao editar.
String _decimalToInput(String raw) {
  final parsed = double.tryParse(raw.trim());
  if (parsed == null) {
    return raw;
  }
  return parsed.toStringAsFixed(2).replaceAll('.', ',');
}

/// Aceita vírgula ou ponto como separador decimal e devolve uma string
/// decimal com ponto e 2 casas, pronta para o numeric(12,2) do banco.
/// Retorna null se o texto não for um número válido ou for negativo.
String? _parseMoneyInput(String text) {
  final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
  final value = double.tryParse(normalized);
  if (value == null || value < 0) {
    return null;
  }
  return value.toStringAsFixed(2);
}

/// Exibe "1500.00" como "R$ 1.500,00", com separador de milhar.
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