// CHANGELOG
// 2026-09-19: "Compartilhar flyer" virou "Compartilhar" — não anexa mais a
// imagem (WhatsApp/Facebook/Telegram/X não recebem arquivo por link, só
// texto/URL) nem depende de haver coverUrl. Abre bottom sheet só com WhatsApp
// e X: evento não tem página pública (diferente de campanha, que tem
// /c/:slug), e Facebook/Telegram exigem link pra funcionar, então ficaram de
// fora aqui (mas continuam em campaigns_admin_page.dart e
// campaign_detail_page.dart). Texto: nome do evento + local + data.
// Removidas as dependências http e cross_file, não usadas mais neste arquivo.
// 2026-09-19: Adicionado "Compartilhar flyer" ao detalhe do evento (só quando
// há coverUrl), baixando os bytes via http.get e compartilhando com
// Share.shareXFiles (share_plus) usando XFile.fromData — sem gravar em disco,
// funciona em web e mobile. mimeType/extensão vêm do header content-type da
// resposta, com fallback para image/jpeg. Botão desabilita durante _busy,
// como as demais ações; erro de download cai no mesmo _snack genérico.
// 2026-09-19: P10 (Trilha G) — criada a página de eventos
// (lib/features/events/presentation/events_page.dart). Recebe tenantId, como
// OrdersPage/PaymentsPage (a rota com ?tenant=<id> precisa ser registrada no
// router.dart, que esta trilha não edita).
// - Lista eventos (flyer, nome, local, data, capacidade, status em português)
//   com loading, erro com "Tentar novamente" e estado vazio.
// - Detalhe em bottom sheet com ações conforme o status: Editar (draft/
//   published), Publicar (draft), Finalizar (published), Cancelar (draft/
//   published). Publicar, finalizar e cancelar pedem confirmação.
// - A página controla o estado "ocupado" (barra de progresso + botões
//   desabilitados) e faz try/catch em cada ação, exibindo EventsException.
// - "Novo evento" e "Editar" abrem EventFormPage (profileType 'event' só define
//   o título; tenantId já é conhecido, então não chama ensureWorkspace).
//   Contrato com o formulário: Navigator.pop(true) ao salvar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../shared/services/whatsapp_service.dart';
import '../../../shared/services/x_service.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'event_form_page.dart';
import 'events_controller.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({required this.tenantId, super.key});
  final String tenantId;

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  bool _busy = false;

  EventsController get _controller =>
      ref.read(eventsControllerProvider(widget.tenantId).notifier);

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsControllerProvider(widget.tenantId));
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Novo evento')),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: events.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
                message: _message(error), onRetry: () => _controller.refresh()),
            data: (items) => items.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
                    onRefresh: () => _controller.refresh(),
                    child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.md, AppSpacing.md, 88),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, index) => _EventTile(
                            event: items[index],
                            coverUrl: _coverUrl(items[index]),
                            onTap: () => _showDetails(items[index]))),
                  ),
          ),
        ),
      ]),
    );
  }

  String? _coverUrl(SambaEvent event) => ref
      .read(eventsRepositoryProvider)
      .getCoverImageUrl(event.coverImagePath);

  Future<void> _openForm({SambaEvent? event}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => EventFormPage(
            profileType: 'event',
            tenantId: widget.tenantId,
            event: event)));
    if (saved == true && mounted) await _controller.refresh();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _snack(success);
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _message(Object error) => error is EventsException
      ? error.message
      : 'Não foi possível concluir a ação. Tente novamente.';

  Future<bool> _confirm(
      {required String title,
      required String text,
      required String confirmLabel}) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(text),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Voltar')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(confirmLabel)),
                ]));
    return result ?? false;
  }

  void _showDetails(SambaEvent event) {
    if (_busy) return;
    final coverUrl = _coverUrl(event);
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (coverUrl != null) ...[
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(coverUrl,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink())),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Row(children: [
                        Expanded(
                            child: Text(event.name,
                                style:
                                    AppTypography.textTheme.headlineSmall)),
                        _StatusChip(
                            label: _statusLabel(event.status),
                            color: _statusColor(event.status)),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      Text('Local: ${_venue(event)}'),
                      Text('Início: ${_dateTime(event.startsAt)}'),
                      if (event.endsAt != null)
                        Text('Término: ${_dateTime(event.endsAt!)}'),
                      Text(event.capacity == null
                          ? 'Capacidade: sem limite definido'
                          : 'Capacidade: ${event.capacity}'),
                      Text('Slug público: ${event.slug}'),
                      if (event.publishedAt != null)
                        Text(
                            'Publicado em ${_dateTime(event.publishedAt!)}'),
                      if (event.description != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(event.description!),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      ..._actions(sheetContext, event),
                    ]))));
  }

  Future<void> _openShareSheet(SambaEvent event) async {
    if (!mounted) return;
    final details = '${_venue(event)} — ${_dateTime(event.startsAt)}';
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Compartilhar', style: AppTypography.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                      leading: const Icon(Icons.chat_outlined),
                      title: const Text('WhatsApp'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openLink(WhatsappService.buildShareUri(
                            message: 'Confira o evento "${event.name}"\n$details'));
                      }),
                  ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: const Text('X (Twitter)'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openLink(XService.buildTextUri(title: event.name, text: details));
                      }),
                ]))));
  }

  Future<void> _openLink(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) _snack('Não foi possível abrir o link de compartilhamento.');
  }

  List<Widget> _actions(BuildContext sheetContext, SambaEvent event) {
    final canEdit = event.isDraft || event.isPublished;
    Widget button(String label, IconData icon, VoidCallback onPressed) =>
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: OutlinedButton.icon(
                onPressed: _busy ? null : onPressed,
                icon: Icon(icon),
                label: Text(label)));

    return [
      button('Compartilhar', Icons.share_outlined, () {
        Navigator.pop(sheetContext);
        _openShareSheet(event);
      }),
      if (canEdit)
        button('Editar', Icons.edit_outlined, () {
          Navigator.pop(sheetContext);
          _openForm(event: event);
        }),
      if (event.isDraft)
        button('Publicar', Icons.publish_outlined, () async {
          Navigator.pop(sheetContext);
          final ok = await _confirm(
              title: 'Publicar evento?',
              text: '"${event.name}" ficará visível para venda de ingressos.',
              confirmLabel: 'Publicar');
          if (ok) {
            await _run(() => _controller.publish(event.id),
                'Evento publicado.');
          }
        }),
      if (event.isPublished)
        button('Finalizar', Icons.flag_outlined, () async {
          Navigator.pop(sheetContext);
          final ok = await _confirm(
              title: 'Finalizar evento?',
              text: 'Depois de finalizado, o evento não poderá mais ser editado.',
              confirmLabel: 'Finalizar');
          if (ok) {
            await _run(() => _controller.finish(event.id),
                'Evento finalizado.');
          }
        }),
      if (canEdit)
        button('Cancelar evento', Icons.cancel_outlined, () async {
          Navigator.pop(sheetContext);
          final ok = await _confirm(
              title: 'Cancelar evento?',
              text:
                  'Esta ação não pode ser desfeita. Ingressos já vendidos não são estornados automaticamente.',
              confirmLabel: 'Cancelar evento');
          if (ok) {
            await _run(() => _controller.cancel(event.id),
                'Evento cancelado.');
          }
        }),
    ];
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(
      {required this.event, required this.coverUrl, required this.onTap});
  final SambaEvent event;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Abrir evento ${event.name}',
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl != null
                ? Image.network(coverUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _CoverPlaceholder())
                : const _CoverPlaceholder()),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(
                    child: Text(event.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.textTheme.titleMedium)),
                _StatusChip(
                    label: _statusLabel(event.status),
                    color: _statusColor(event.status)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Text(_dateTime(event.startsAt),
                  style: AppTypography.textTheme.bodySmall),
              Text(_venue(event),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted)),
              if (event.capacity != null)
                Text('Capacidade: ${event.capacity}',
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted)),
            ])),
      ]),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
      width: 64,
      height: 64,
      color: AppColors.peach,
      child: const Icon(Icons.image_outlined, color: AppColors.wine));
}

Color _statusColor(String status) => switch (status) {
      'published' => AppColors.success,
      'cancelled' => AppColors.error,
      'finished' => AppColors.muted,
      _ => AppColors.orange
    };

String _statusLabel(String status) => switch (status) {
      'published' => 'Publicado',
      'cancelled' => 'Cancelado',
      'finished' => 'Finalizado',
      _ => 'Rascunho'
    };

String _venue(SambaEvent event) {
  final name = event.venueName;
  if (name == null) return 'Local não informado';
  final city = event.venueCity;
  return city == null || city.isEmpty ? name : '$name — $city';
}

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} às ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
          child: Text('Ainda não há eventos. Toque em "Novo evento" para criar o primeiro.',
              textAlign: TextAlign.center)));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
                onPressed: onRetry, child: const Text('Tentar novamente')),
          ])));
}