// Changelog:
// 2026-09-23 (2): Botão "Excluir campanha" no AppBar (ícone de lixeira, à
// direita de Editar), com confirmação antes de excluir — mesmo padrão de
// _confirmDeleteProduct(). Chama CampaignsRepository.remove() (soft delete,
// ver changelog de campaigns_repository.dart). Enquanto exclui, usa
// _actionLoading para desabilitar os botões do AppBar. Em caso de sucesso,
// volta para a lista de campanhas do tenant (a campanha excluída não existe
// mais para esta tela); em caso de erro, mostra snackbar e permanece aqui.
// 2026-09-23: Arquivo 4/4 da correção do slug quebrado. _CampaignEditForm
// (formulário de edição) tinha o mesmo problema já corrigido em
// campaigns_admin_page.dart: preview "Link: /.../..." e o validador do campo
// Slug público faziam só value.text.trim(), deixando espaço/acento passar
// direto (a normalização real de fato acontece em
// CampaignsRepository.update(), que já chama slugify() — ver changelog de
// campaigns_repository.dart — mas a UI aqui nunca refletia o formato final
// nem bloqueava um slug que viraria vazio após normalizar, ex.: "!!!").
// Preview e validador agora usam slugify() (lib/core/utils/slug.dart), igual
// ao formulário de criação. Não pré-preenche a partir de evento porque este
// é o formulário de EDIÇÃO de uma campanha já existente, não de criação —
// esse pré-preenchimento já existe em _CampaignForm (campaigns_admin_page.dart).
// 2026-09-22: Link público trocado de /c/:slug para /:tenantSlug/:campaignSlug
// (decisão do usuário — ver router.dart, campaigns_repository.dart). O
// preview "/c/<slug>" no corpo da página e no formulário de edição
// (_CampaignEditForm) virou "/<tenantSlug>/<slug>", lendo
// campaign['tenants']['slug'] (novo embed de CampaignsRepository.getAdmin()
// — já chega pronto em widget.campaign, sem busca extra, diferente do
// formulário de criação em campaigns_admin_page.dart). _openShareSheet()
// passou tenantSlug + slug (nomeados) para AppConfig.campaignShareUrl(),
// que trocou de assinatura.
// 2026-09-19: Ícone "Compartilhar" agora abre um bottom sheet com WhatsApp,
// Facebook, Telegram e X (Twitter), cada um usando o service correspondente
// em lib/shared/services/ (buildCampaignUri) e url_launcher (launchUrl) para
// abrir. Trocado o Share.share (share_plus) direto da rodada anterior — que
// ignorava ShareService — para restaurar o contrato do domínio.
// 2026-09-19: Adicionado ícone "Compartilhar" no AppBar (ao lado de Editar),
// usando Share.share (share_plus) com o link público montado por
// AppConfig.campaignShareUrl(slug) — mesmo padrão de campaigns_admin_page.dart
// (config lido via ProviderScope.containerOf(context, listen:
// false).read(appConfigProvider), página continua StatefulWidget). Também
// adicionado o preview "Link: /c/<slug>" em tempo real no campo Slug do
// formulário de edição (_CampaignEditForm), igual ao já feito em
// campaigns_admin_page.dart para o formulário de criação.
// 2026-09-18: Item 9 (Campaigns) —
// 1) Adicionado botão de editar campanha (nome/slug/descrição), usando
//    CampaignsRepository.update() que não existia antes.
// 2) Substituído o botão único "Publicar" por ações condicionadas ao status
//    real (draft/published/paused/finished, confirmado via pg_constraint):
//    draft -> Publicar; published -> Pausar/Finalizar; paused ->
//    Republicar/Finalizar (Republicar reusa publish(), que já seta
//    status='published' a partir de qualquer status); finished -> nenhuma
//    ação (estado terminal).
// 3) Adicionada confirmação antes de excluir produto (faltava — item 19
//    exige confirmação em toda exclusão).
// 4) publish()/pause()/finish()/deleteProduct() agora têm try/catch +
//    feedback de erro e loading local nos botões; antes falhavam em
//    silêncio.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/slug.dart';
import '../../../core/widgets/app_input.dart';
import '../../../shared/services/facebook_service.dart';
import '../../../shared/services/telegram_service.dart';
import '../../../shared/services/whatsapp_service.dart';
import '../../../shared/services/x_service.dart';
import '../data/campaigns_repository.dart';

class CampaignDetailPage extends StatefulWidget {
  const CampaignDetailPage({required this.campaignId, super.key});

  final String campaignId;

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  final _repo = CampaignsRepository();
  Map<String, dynamic>? _campaign;
  List<Map<String, dynamic>> _products = const [];
  bool _loading = true;
  bool _loadError = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      _campaign = await _repo.getAdmin(widget.campaignId);
      _products = await _repo.listProducts(widget.campaignId);
    } catch (_) {
      _loadError = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final campaign = _campaign;
    if (campaign == null || _loadError) {
      return Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Não foi possível carregar a campanha.'),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Tentar novamente', onPressed: _load),
      ])));
    }
    final status = campaign['status']?.toString() ?? 'draft';
    return Scaffold(
      appBar: AppBar(title: Text(campaign['name'].toString()), actions: [
        IconButton(
            tooltip: 'Compartilhar',
            onPressed: _actionLoading ? null : () => _openShareSheet(campaign),
            icon: const Icon(Icons.share_outlined)),
        IconButton(
            tooltip: 'Editar campanha',
            onPressed: _actionLoading ? null : _editCampaign,
            icon: const Icon(Icons.edit_outlined)),
        IconButton(
            tooltip: 'Excluir campanha',
            onPressed: _actionLoading ? null : () => _confirmDeleteCampaign(campaign),
            icon: const Icon(Icons.delete_outline, color: AppColors.error)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        onPressed: () => _openProduct(),
        icon: const Icon(Icons.add),
        label: const Text('Novo ingresso'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(campaign['description']?.toString() ?? 'Sem descrição',
                      style: AppTypography.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('/${_tenantSlug(campaign)}/${campaign['slug']}',
                      style: AppTypography.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Chip(label: Text(_statusLabel(status))),
                    const Spacer(),
                  ]),
                  if (_statusActions(status).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _statusActions(status)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Ingressos e produtos', style: AppTypography.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            if (_products.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Cadastre o primeiro ingresso ou produto.',
                      textAlign: TextAlign.center))
            else
              ..._products.map(_productTile),
          ],
        ),
      ),
    );
  }

  Future<void> _openShareSheet(Map<String, dynamic> campaign) async {
    final config = ProviderScope.containerOf(context, listen: false).read(appConfigProvider);
    final name = campaign['name']?.toString() ?? 'Campanha';
    final url = config.campaignShareUrl(
      tenantSlug: _tenantSlug(campaign),
      campaignSlug: campaign['slug']?.toString() ?? '',
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

  /// Slug do tenant, vindo do embed tenants(slug) de
  /// CampaignsRepository.getAdmin().
  String _tenantSlug(Map<String, dynamic> campaign) =>
      (campaign['tenants'] as Map?)?['slug']?.toString() ?? '';

  List<Widget> _statusActions(String status) => switch (status) {
        'draft' => [
            AppButton(
                label: 'Publicar',
                size: AppButtonSize.small,
                isLoading: _actionLoading,
                onPressed: () => _changeStatus(_repo.publish, 'publicar')),
          ],
        'published' => [
            AppButton(
                label: 'Pausar',
                size: AppButtonSize.small,
                variant: AppButtonVariant.outline,
                isLoading: _actionLoading,
                onPressed: () => _changeStatus(_repo.pause, 'pausar')),
            AppButton(
                label: 'Finalizar',
                size: AppButtonSize.small,
                isLoading: _actionLoading,
                onPressed: () => _changeStatus(_repo.finish, 'finalizar')),
          ],
        'paused' => [
            AppButton(
                label: 'Republicar',
                size: AppButtonSize.small,
                isLoading: _actionLoading,
                onPressed: () => _changeStatus(_repo.publish, 'republicar')),
            AppButton(
                label: 'Finalizar',
                size: AppButtonSize.small,
                variant: AppButtonVariant.outline,
                isLoading: _actionLoading,
                onPressed: () => _changeStatus(_repo.finish, 'finalizar')),
          ],
        _ => const [],
      };

  Future<void> _changeStatus(
      Future<void> Function(String id) action, String verb) async {
    setState(() => _actionLoading = true);
    try {
      await action(widget.campaignId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível $verb a campanha.')));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Widget _productTile(Map<String, dynamic> product) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product['name'].toString(), style: AppTypography.textTheme.titleMedium),
          Text(_typeLabel(product['type'].toString()),
              style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          Text('R\$ ${product['price'].toString().replaceAll('.', ',')}',
              style: AppTypography.textTheme.titleSmall?.copyWith(color: AppColors.wine)),
        ])),
        IconButton(
            tooltip: 'Editar',
            onPressed: () => _openProduct(product: product),
            icon: const Icon(Icons.edit_outlined)),
        IconButton(
            tooltip: 'Excluir',
            onPressed: () => _confirmDeleteProduct(product),
            icon: const Icon(Icons.delete_outline, color: AppColors.error)),
      ]),
    );
  }

  Future<void> _confirmDeleteCampaign(Map<String, dynamic> campaign) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Excluir campanha'),
              content: Text(
                  'Tem certeza que deseja excluir "${campaign['name']}"? '
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
    setState(() => _actionLoading = true);
    try {
      await _repo.remove(widget.campaignId);
    } catch (_) {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível excluir a campanha.')));
      }
      return;
    }
    if (!mounted) return;
    // A campanha não existe mais para esta tela: volta para a lista do tenant.
    context.go('/campaigns?tenant=${campaign['tenant_id']}');
  }

  Future<void> _confirmDeleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Excluir produto'),
              content: Text(
                  'Tem certeza que deseja excluir "${product['name']}"? Essa ação não pode ser desfeita.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Excluir')),
              ],
            ));
    if (confirmed != true) return;
    try {
      await _repo.deleteProduct(product['id'].toString());
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível excluir o produto.')));
      }
    }
  }

  Future<void> _editCampaign() async {
    final campaign = _campaign!;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CampaignEditForm(repo: _repo, campaign: campaign),
    );
    if (result == true) _load();
  }

  Future<void> _openProduct({Map<String, dynamic>? product}) async {
    final campaign = _campaign!;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductForm(
        repo: _repo,
        tenantId: campaign['tenant_id'].toString(),
        campaignId: widget.campaignId,
        product: product,
      ),
    );
    if (result == true) _load();
  }

  String _typeLabel(String type) => switch (type) {
        'ticket' => 'Ingresso',
        'combo' => 'Combo',
        'table' => 'Mesa',
        'vip' => 'VIP',
        'courtesy' => 'Cortesia',
        _ => type,
      };
}

class _CampaignEditForm extends StatefulWidget {
  const _CampaignEditForm({required this.repo, required this.campaign});
  final CampaignsRepository repo;
  final Map<String, dynamic> campaign;
  @override
  State<_CampaignEditForm> createState() => _CampaignEditFormState();
}

class _CampaignEditFormState extends State<_CampaignEditForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.campaign['name']?.toString());
  late final _slug = TextEditingController(text: widget.campaign['slug']?.toString());
  late final _description =
      TextEditingController(text: widget.campaign['description']?.toString());
  bool _saving = false;

  /// Slug do tenant, vindo do embed tenants(slug) de
  /// CampaignsRepository.getAdmin() — chega pronto em widget.campaign.
  String _tenantSlug() =>
      (widget.campaign['tenants'] as Map?)?['slug']?.toString() ?? '';

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md),
          child: Form(
              key: _key,
              child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Editar campanha', style: AppTypography.textTheme.headlineSmall),
                const SizedBox(height: 16),
                AppInput(
                    label: 'Nome',
                    controller: _name,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome.' : null),
                AppInput(
                    label: 'Slug público',
                    controller: _slug,
                    validator: (v) => slugify(v ?? '').isEmpty ? 'Informe o slug.' : null),
                ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _slug,
                    builder: (_, value, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Link: /${_tenantSlug()}/${slugify(value.text)}',
                            style: AppTypography.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted)))),
                AppInput(label: 'Descrição', controller: _description, maxLines: 3),
                const SizedBox(height: 16),
                AppButton(
                    label: 'Salvar alterações',
                    isFullWidth: true,
                    isLoading: _saving,
                    onPressed: _save),
              ])))));

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repo.update(
          id: widget.campaign['id'].toString(),
          name: _name.text,
          slug: _slug.text,
          description: _description.text);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível salvar a campanha.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({required this.repo, required this.tenantId, required this.campaignId, this.product});

  final CampaignsRepository repo;
  final String tenantId;
  final String campaignId;
  final Map<String, dynamic>? product;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?['name']?.toString());
  late final _price = TextEditingController(text: widget.product?['price']?.toString());
  late final _description = TextEditingController(text: widget.product?['description']?.toString());
  late final _stock = TextEditingController(text: widget.product?['stock_quantity']?.toString());
  String _type = 'ticket';
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.product?['type']?.toString() ?? 'ticket';
    _active = widget.product?['is_active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md),
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.product == null ? 'Novo ingresso/produto' : 'Editar produto', style: AppTypography.textTheme.headlineSmall),
              const SizedBox(height: 16),
              AppInput(label: 'Nome', controller: _name, validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome.' : null),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'ticket', child: Text('Ingresso')),
                  DropdownMenuItem(value: 'combo', child: Text('Combo')),
                  DropdownMenuItem(value: 'table', child: Text('Mesa')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP')),
                  DropdownMenuItem(value: 'courtesy', child: Text('Cortesia')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'ticket'),
              ),
              AppInput(label: 'Preço (R\$)', controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _priceValidator),
              AppInput(label: 'Estoque (opcional)', controller: _stock, keyboardType: TextInputType.number),
              AppInput(label: 'Descrição', controller: _description, maxLines: 2),
              SwitchListTile.adaptive(value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Produto ativo'), contentPadding: EdgeInsets.zero),
              const SizedBox(height: 12),
              AppButton(label: 'Salvar produto', isFullWidth: true, isLoading: _saving, onPressed: _save),
            ]),
          ),
        ),
      ),
    );
  }

  String? _priceValidator(String? value) {
    final normalized = value?.trim().replaceAll(',', '.');
    if (normalized == null || normalized.isEmpty || !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
      return 'Informe um preço válido.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      if (widget.product == null) {
        await widget.repo.createProduct(tenantId: widget.tenantId, campaignId: widget.campaignId, name: _name.text, type: _type, price: _price.text, description: _description.text, stockQuantity: int.tryParse(_stock.text));
      } else {
        await widget.repo.updateProduct(id: widget.product!['id'].toString(), name: _name.text, type: _type, price: _price.text, description: _description.text, stockQuantity: int.tryParse(_stock.text), isActive: _active);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível salvar o produto.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}