// CHANGELOG
// 2026-09-23 (4): Fluxo de ingressos (opção B): ingressos e preços continuam
// sendo cadastrados no detalhe da campanha ("Novo ingresso"), mas depois de
// criar a campanha o app agora abre direto o detalhe dela, em vez de voltar
// para a lista. _CampaignForm passou a fechar com o id da campanha criada
// (antes: true) e _openCreate navega para /campaigns/<id>?tenant=<tenantId>,
// com um aviso para cadastrar os ingressos. Nenhuma outra lógica alterada.
// 2026-09-23 (3): Implementado _confirmDelete(), que era chamado no _tile mas
// não existia (erro de compilação). Diálogo de confirmação + remove()
// (soft delete) + snackbar de erro, com _deletingIds para desabilitar o
// botão do item durante a exclusão. Mesmo padrão de
// _confirmDeleteCampaign() em campaign_detail_page.dart.
// 2026-09-23 (2): Botão "Excluir" em cada item da lista (soft delete via
// CampaignsRepository.remove(), ver changelog de campaigns_repository.dart),
// com confirmação antes de excluir — mesmo padrão de
// _confirmDeleteProduct em campaign_detail_page.dart.
// 2026-09-23: Duas correções no formulário de criação (_CampaignForm):
// - Preview "Link: /.../..." e o valor salvo em _save() agora passam por
//   slugify() (lib/core/utils/slug.dart) em vez de só value.text.trim().
//   Causa raiz confirmada: o campo deixava o usuário digitar espaço/acento
//   livremente e nada removia isso antes de mostrar ou salvar, gerando link
//   quebrado tipo "/luuma-restaurante/samba com feijoada". A normalização
//   real também foi movida pro repositório (CampaignsRepository.create()),
//   isso aqui é só a UI mostrando o formato final enquanto o usuário digita.
// - _onEventChanged agora também pré-preenche Nome e Descrição a partir do
//   evento escolhido (widget.events já traz description desde a mudança em
//   CampaignsRepository.listEvents()), mesma regra do slug: só preenche se
//   o campo ainda estiver vazio, pra não sobrescrever edição manual do
//   usuário ao trocar de evento depois de já ter digitado algo.
// 2026-09-22: Link público trocado de /c/:slug para /:tenantSlug/:campaignSlug
// (decisão do usuário — ver router.dart, campaigns_repository.dart). O
// preview "/c/<slug>" no tile virou "/<tenantSlug>/<slug>", lendo
// item['tenants']['slug'] (novo embed de CampaignsRepository.listAdmin()).
// _openShareSheet() passou tenantSlug + slug (nomeados) para
// AppConfig.campaignShareUrl(), que trocou de assinatura. No formulário de
// criação (_CampaignForm), o dropdown de evento agora pré-preenche o campo
// Slug público com o slug do evento escolhido (widget.events já traz slug
// desde a mudança em CampaignsRepository.listEvents()) — só quando o campo
// ainda está vazio, pra não sobrescrever edição manual do usuário se ele
// trocar de evento depois de digitar um slug próprio. _CampaignForm passou
// a receber tenantSlug (buscado em _openCreate via
// CampaignsRepository.getTenantSlug(), já que na criação ainda não existe
// campanha com embed tenants(slug)), usado no preview "Link:
// /<tenantSlug>/<slug>" em tempo real (antes fixo em "/c/<slug>").
// 2026-09-19: Ícone "Compartilhar" agora abre um bottom sheet com WhatsApp,
// Facebook, Telegram e X (Twitter), cada um usando o service correspondente
// em lib/shared/services/ (buildCampaignUri) para montar o Uri e
// url_launcher (launchUrl) para abrir. Trocado o Share.share (share_plus)
// direto da rodada anterior — que ignorava ShareService — para restaurar o
// contrato do domínio.
// 2026-09-19: Adicionado ícone "Compartilhar" em cada item da lista, usando
// Share.share (share_plus) com o link público montado por
// AppConfig.campaignShareUrl(slug) (config lido via
// ProviderScope.containerOf(context, listen: false).read(appConfigProvider) —
// a página continua StatefulWidget, sem virar ConsumerStatefulWidget, para não
// alargar o escopo da mudança). "Ingresso" e "catálogo de produtos" reusam o
// mesmo link, por decisão do usuário (não existe link individual para
// nenhum dos dois).
// 2026-09-19: _CampaignForm (criação) agora mostra "Link: /c/<slug>" em tempo
// real abaixo do campo Slug público, via ValueListenableBuilder ouvindo _slug
// (TextEditingController já é ValueListenable<TextEditingValue>, sem listener
// manual). Nenhuma outra lógica foi alterada.
// - Corrigido: expected_token na build() de _CampaignFormState (linha do widget.
//   SafeArea(child: Padding(child: Form(child: SingleChildScrollView(child: Column(...))))
//   faltava 1 parêntese de fechamento no final da cadeia -- confirmado por contagem
//   programática de parênteses (depth final = 1 antes da correção, 0 depois).
// - Nenhuma outra lógica foi alterada.
// 2026-09-18: Item 9 (Campaigns) — publicar direto da listagem agora trata
// erro (snackbar) e mostra loading por item (_publishingIds), antes falhava
// em silêncio. Atalho de publicar restrito a status == 'draft': pausar,
// finalizar e republicar (paused -> published) já ficam no detalhe da
// campanha, que tem as ações completas dessas transições. listEvents() em
// _openCreate também passou a tratar erro em vez de deixar a exception subir
// sem feedback.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/slug.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../../../shared/services/facebook_service.dart';
import '../../../shared/services/telegram_service.dart';
import '../../../shared/services/whatsapp_service.dart';
import '../../../shared/services/x_service.dart';
import '../data/campaigns_repository.dart';

class CampaignsAdminPage extends StatefulWidget {
  const CampaignsAdminPage({required this.tenantId, super.key});
  final String tenantId;
  @override
  State<CampaignsAdminPage> createState() => _CampaignsAdminPageState();
}

class _CampaignsAdminPageState extends State<CampaignsAdminPage> {
  final _repo = CampaignsRepository();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  final _publishingIds = <String>{};
  final _deletingIds = <String>{};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { _items = await _repo.listAdmin(tenantId: widget.tenantId); } catch (_) { _error = 'Não foi possível carregar as campanhas.'; }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campanhas')),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: AppColors.orange, foregroundColor: AppColors.white, onPressed: _openCreate, icon: const Icon(Icons.add), label: const Text('Nova campanha')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: AppButton(label: 'Tentar novamente', onPressed: _load)) : RefreshIndicator(onRefresh: _load, child: _items.isEmpty ? ListView(children: [const SizedBox(height: 180), Icon(Icons.campaign_outlined, size: 56, color: AppColors.wine), const SizedBox(height: 16), Text('Nenhuma campanha criada', textAlign: TextAlign.center, style: AppTypography.textTheme.titleLarge)]) : ListView.separated(padding: const EdgeInsets.all(AppSpacing.md), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm), itemBuilder: (_, index) => _tile(_items[index]))),
    );
  }

  Widget _tile(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'draft';
    final id = item['id'].toString();
    final publishing = _publishingIds.contains(id);
    return AppCard(onTap: () => context.go('/campaigns/$id?tenant=${widget.tenantId}'), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['name']?.toString() ?? '', style: AppTypography.textTheme.titleMedium), const SizedBox(height: 4), Text('/${_tenantSlug(item)}/${item['slug']}', style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted))]),), Chip(label: Text(_statusLabel(status))), IconButton(tooltip: 'Compartilhar', onPressed: () => _openShareSheet(item), icon: const Icon(Icons.share_outlined)), if (status == 'draft') publishing ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(tooltip: 'Publicar', onPressed: () => _publish(id), icon: const Icon(Icons.publish_outlined)), IconButton(tooltip: 'Excluir', onPressed: _deletingIds.contains(id) ? null : () => _confirmDelete(item), icon: const Icon(Icons.delete_outline, color: AppColors.error))]));
  }

  /// Slug do tenant, vindo do embed tenants(slug) de
  /// CampaignsRepository.listAdmin(). Vazio se o embed não vier (não deveria
  /// acontecer — tenant_id é FK obrigatória — mas evita null-check quebrar a
  /// tela).
  String _tenantSlug(Map<String, dynamic> item) =>
      (item['tenants'] as Map?)?['slug']?.toString() ?? '';

  Future<void> _openShareSheet(Map<String, dynamic> item) async {
    final config = ProviderScope.containerOf(context, listen: false).read(appConfigProvider);
    final name = item['name']?.toString() ?? 'Campanha';
    final url = config.campaignShareUrl(
      tenantSlug: _tenantSlug(item),
      campaignSlug: item['slug']?.toString() ?? '',
    );
    if (!mounted) return;
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
                        _openLink(WhatsappService.buildCampaignUri(campaignName: name, campaignUrl: url));
                      }),
                  ListTile(
                      leading: const Icon(Icons.facebook_outlined),
                      title: const Text('Facebook'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openLink(FacebookService.buildCampaignUri(campaignName: name, campaignUrl: url));
                      }),
                  ListTile(
                      leading: const Icon(Icons.send_outlined),
                      title: const Text('Telegram'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openLink(TelegramService.buildCampaignUri(campaignName: name, campaignUrl: url));
                      }),
                  ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: const Text('X (Twitter)'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openLink(XService.buildCampaignUri(campaignName: name, campaignUrl: url));
                      }),
                ]))));
  }

  Future<void> _openLink(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link de compartilhamento.')));
    }
  }

  String _statusLabel(String status) => switch (status) {
        'published' => 'Publicada',
        'paused' => 'Pausada',
        'finished' => 'Finalizada',
        _ => 'Rascunho',
      };

  Future<void> _publish(String id) async {
    setState(() => _publishingIds.add(id));
    try {
      await _repo.publish(id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível publicar a campanha.')));
      }
    } finally {
      if (mounted) setState(() => _publishingIds.remove(id));
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Excluir campanha'),
              content: Text(
                  'Tem certeza que deseja excluir "${item['name']}"? '
                  'O link público deixará de funcionar e a campanha sairá da lista. '
                  'Essa ação não pode ser desfeita.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Excluir',
                        style: TextStyle(color: AppColors.error))),
              ],
            ));
    if (confirmed != true) return;
    setState(() => _deletingIds.add(id));
    try {
      await _repo.remove(id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível excluir a campanha.')));
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(id));
    }
  }

  Future<void> _openCreate() async {
    List<Map<String, dynamic>> events;
    String? tenantSlug;
    try {
      events = await _repo.listEvents(tenantId: widget.tenantId);
      tenantSlug = await _repo.getTenantSlug(widget.tenantId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível carregar os eventos.')));
      }
      return;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _CampaignForm(repo: _repo, tenantId: widget.tenantId, tenantSlug: tenantSlug ?? '', events: events));
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.go('/campaigns/$result?tenant=${widget.tenantId}');
    messenger.showSnackBar(const SnackBar(
        content: Text('Campanha criada. Cadastre os ingressos e preços em "Novo ingresso".')));
  }
}

class _CampaignForm extends StatefulWidget {
  const _CampaignForm({required this.repo, required this.tenantId, required this.tenantSlug, required this.events});
  final CampaignsRepository repo; final String tenantId; final String tenantSlug; final List<Map<String, dynamic>> events;
  @override State<_CampaignForm> createState() => _CampaignFormState();
}
class _CampaignFormState extends State<_CampaignForm> {
  final _key = GlobalKey<FormState>(); final _name = TextEditingController(); final _slug = TextEditingController(); final _description = TextEditingController(); String? _eventId; bool _saving = false;
  @override void dispose() { _name.dispose(); _slug.dispose(); _description.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md), child: Form(key: _key, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Nova campanha', style: AppTypography.textTheme.headlineSmall), const SizedBox(height: 16), AppInput(label: 'Nome', controller: _name, validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome.' : null), AppInput(label: 'Slug público', controller: _slug, validator: (v) => slugify(v ?? '').isEmpty ? 'Informe o slug.' : null), ValueListenableBuilder<TextEditingValue>(valueListenable: _slug, builder: (_, value, __) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Link: /${widget.tenantSlug}/${slugify(value.text)}', style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted)))), AppInput(label: 'Descrição', controller: _description, maxLines: 3), DropdownButtonFormField<String>(initialValue: _eventId, decoration: const InputDecoration(labelText: 'Evento'), items: widget.events.map((event) => DropdownMenuItem(value: event['id'].toString(), child: Text(event['name'].toString()))).toList(), onChanged: _onEventChanged, validator: (value) => value == null ? 'Escolha um evento.' : null), const SizedBox(height: 16), AppButton(label: 'Criar campanha', isFullWidth: true, isLoading: _saving, onPressed: _save)])))));

  /// Ao escolher o evento, pré-preenche nome, descrição e slug da campanha
  /// com os dados do evento (widget.events já traz name, description e slug
  /// — ver CampaignsRepository.listEvents()). Só preenche cada campo se ele
  /// ainda estiver vazio, pra não sobrescrever edição manual do usuário ao
  /// trocar de evento depois de já ter digitado algo.
  void _onEventChanged(String? value) {
    setState(() {
      _eventId = value;
      final event = widget.events.firstWhere(
        (event) => event['id'].toString() == value,
        orElse: () => const <String, dynamic>{},
      );
      if (_name.text.trim().isEmpty) {
        final eventName = event['name']?.toString();
        if (eventName != null && eventName.isNotEmpty) _name.text = eventName;
      }
      if (_description.text.trim().isEmpty) {
        final eventDescription = event['description']?.toString();
        if (eventDescription != null && eventDescription.isNotEmpty) {
          _description.text = eventDescription;
        }
      }
      if (_slug.text.trim().isEmpty) {
        final eventSlug = event['slug']?.toString();
        if (eventSlug != null && eventSlug.isNotEmpty) {
          _slug.text = eventSlug;
        }
      }
    });
  }
  Future<void> _save() async { if (!(_key.currentState?.validate() ?? false)) return; setState(() => _saving = true); try { final created = await widget.repo.create(tenantId: widget.tenantId, eventId: _eventId!, name: _name.text, slug: slugify(_slug.text), description: _description.text); if (mounted) Navigator.pop(context, created['id'].toString()); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível criar a campanha.'))); } finally { if (mounted) setState(() => _saving = false); } }
}