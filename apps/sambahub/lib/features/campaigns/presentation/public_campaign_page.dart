// CHANGELOG
// 2026-09-22: Unificação de carrinho (campanha + catálogo) — último arquivo
// do plano de unificação de checkout.
// - Widget/State: PublicCampaignPage virou ConsumerStatefulWidget e
//   _PublicCampaignPageState virou ConsumerState (única mudança na
//   declaração — _cart/_catalogCart e toda a UI de seleção continuam
//   controlando +/-, badges etc. exatamente como antes).
// - _openCheckout(): parou de abrir o showModalBottomSheet com formulário
//   (nome/e-mail/telefone) e de chamar CampaignsRepository.createPublicOrder
//   direto. Agora resolve os ids de _cart contra campaign.products e os ids
//   de _catalogCart contra _menu (via helpers _findCampaignProduct/
//   _findCatalogProduct, mesmo padrão de busca de _catalogSection), alimenta
//   cartControllerProvider com CartProductRef.fromCampaignProduct/
//   fromCatalogProduct (quantity = quantidade já acumulada em cada mapa) e
//   navega para context.go('/checkout?campaign=${campaign.id}') — query
//   param confirmado em router.dart. Deixou de ser async (não há mais
//   nenhum await no método). CampaignsRepository.createPublicOrder fica sem
//   chamador neste arquivo; não foi removido do repositório (outras telas
//   podem usar — a decidir separadamente).
// - _cart/_catalogCart NÃO são mais limpos aqui: quem esvazia o carrinho
//   agora é o fluxo de checkout_page.dart após o pedido ser criado de fato.
// - Import de app_input.dart removido (só era usado no formulário do modal
//   que saiu). Imports novos: flutter_riverpod, go_router, cart_item.dart
//   (CartProductRef) e cart_controller.dart (cartControllerProvider).
// - _trustSection(): removida a frase "e ingresso enviado para o seu
//   e-mail" — não reflete mais a dinâmica real (pagamento/confirmação
//   passam pelo checkout_page.dart / Mercado Pago, não por e-mail).
// 2026-09-20 (4): Contador de favoritos. O coração do AppBar agora persiste
// no banco e mostra a contagem ao lado. _favorite deixou de ser um bool
// local: o estado (contagem + se este dispositivo já favoritou) é carregado
// em _loadFavorites() junto com a campanha, e _toggleFavorite() chama
// CampaignsRepository.toggleFavorite() e usa a contagem devolvida. O id do
// dispositivo vem de DeviceIdService (anônimo, sem login). Se o carregamento
// falhar (ex.: migration não aplicada) o contador fica oculto e a página
// segue normal; se o toggle falhar, mostra mensagem. Nenhuma outra lógica
// alterada.
// 2026-09-20 (3): Botão "Convites Vips" + badge de vagas no hero.
// - _hero(): "Bora garantir" virou "Convites Vips"; o ícone do WhatsApp ao
//   lado foi substituído por um badge (_vipBadge) com o nº de vagas VIP
//   restantes ("N vagas") ou "Esgotado". Vagas = soma de stockQuantity dos
//   produtos type 'vip' ativos (CampaignsRepository.create() gera esse
//   produto a partir de events.vip_quantity; a RPC de pedido baixa o
//   estoque). Sem produto VIP, ou com VIP sem limite (stockQuantity null),
//   o badge não aparece. WhatsApp continua em "Convidar um amigo" e em
//   "Compartilhar".
// - Rolagem do botão: _goToProducts() agora usa GlobalKey (_productsKey) na
//   seção de produtos + Scrollable.ensureVisible. O offset fixo 340 ficou
//   errado depois do flyer 9:16 inteiro; _productsOffset() agora estima a
//   altura do flyer e serve só de fallback quando a seção ainda não foi
//   construída pelo ListView.
// - Favoritos (contador) NÃO foi alterado: exige tabela/RPC no Supabase.
// 2026-09-20 (2): Flyer e ícone do cardápio:
// - _hero(): flyer 9:16 agora aparece inteiro (AspectRatio 9/16 + BoxFit.contain,
//   largura máx. 480 px centralizada, fundo wineDeep nas laterais em telas
//   largas). Antes: SizedBox(height: 360) + BoxFit.cover cortava topo/base
//   (data/local do flyer) e o gradiente sobrepunha o botão. Título, evento e
//   botões (Bora garantir / WhatsApp) saíram do Stack e ficam num bloco
//   wineDeep logo abaixo do flyer. Sem imagem: fallback com altura 240 + o
//   mesmo bloco. A rolagem já existia (ListView do build()), sem mudança.
// - _catalogProductCard(): ícone Icons.restaurant_menu_outlined ->
//   Icons.sports_bar_outlined. _productIcon() (ingressos) não foi alterado.
// 2026-09-20: Duas melhorias na campanha pública (Trilha catálogo público):
// - Flyer: _hero() agora resolve coverImagePath via
//   CampaignsRepository.getCoverImageUrl() (bucket 'event-covers', público)
//   em vez de passar o path bruto de storage direto pro Image.network(), que
//   nunca resolvia pra imagem nenhuma.
// - Catálogo: após carregar a campanha, _loadCatalog() busca
//   CatalogRepository.fetchMenu(campaign.tenantId) (RLS pública já filtra
//   por is_active + campanha publicada, ver migração
//   2026_09_20_catalog_in_public_checkout.sql). Falha ao carregar o catálogo
//   não bloqueia a página — é conteúdo complementar, _menu fica null e a
//   seção simplesmente não aparece.
// - Carrinho: itens de catálogo usam um Map separado (_catalogCart), nunca
//   misturado com _cart (ids de campaign_products), evitando qualquer risco
//   de colisão de chave entre as duas tabelas. _totalItems() e a visibilidade
//   da cartBar agora consideram os dois mapas.
// - Checkout: _openCheckout() passa catalogProducts: _catalogCart pro
//   repository (CheckoutRepository/CampaignsRepository.createPublicOrder já
//   aceitam o parâmetro, ver changelogs desses arquivos); os dois carrinhos
//   são limpos juntos após sucesso.
// 2026-09-22: Link público trocado de /c/:slug para
// /:tenantSlug/:campaignSlug (decisão do usuário — ver router.dart e
// campaigns_repository.dart). PublicCampaignPage passou a receber
// tenantSlug + campaignSlug em vez de um único slug; _load() chama
// CampaignsRepository.findByTenantAndCampaignSlug(). Nenhuma outra lógica
// alterada.
// 2026-09-19: Corrigidos 2 erros expected_token (parêntese de fechamento
// faltando) apontados pelo dart analyze:
// - _errorView(), linha do Center(...): faltava 1 ')' pra fechar o Center
//   antes da vírgula do parâmetro body:.
// - _openCheckout(), fim da cadeia StatefulBuilder(...SafeArea(...Padding(
//   ...Form(...SingleChildScrollView(...Column(...))))): faltava 1 ')' pra
//   fechar o StatefulBuilder.
// Confirmado por contagem programática de parênteses/chaves/colchetes no
// arquivo inteiro (profundidade final = 0 nos três, ignorando strings e
// comentários de linha). Nenhuma outra lógica foi alterada.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../shared/services/device_id_service.dart';
import '../../../shared/services/share_service.dart';
import '../../../shared/services/whatsapp_service.dart';
import '../../cart/domain/cart_item.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_category.dart';
import '../../catalog/domain/catalog_product.dart';
import '../../catalog/domain/menu.dart';
import '../data/campaigns_repository.dart';
import '../domain/public_campaign.dart';

class PublicCampaignPage extends ConsumerStatefulWidget {
  const PublicCampaignPage({
    required this.tenantSlug,
    required this.campaignSlug,
    super.key,
  });

  final String tenantSlug;
  final String campaignSlug;

  @override
  ConsumerState<PublicCampaignPage> createState() => _PublicCampaignPageState();
}

class _PublicCampaignPageState extends ConsumerState<PublicCampaignPage> {
  final CampaignsRepository _repository = CampaignsRepository();
  final CatalogRepository _catalogRepository = CatalogRepository();
  final Map<String, int> _cart = <String, int>{};
  final Map<String, int> _catalogCart = <String, int>{};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _productsKey = GlobalKey();

  PublicCampaign? _campaign;
  Menu? _menu;
  bool _loading = true;
  bool _favorite = false;
  int? _favoriteCount;
  bool _togglingFavorite = false;
  String? _deviceId;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final campaign = await _repository.findByTenantAndCampaignSlug(
        tenantSlug: widget.tenantSlug,
        campaignSlug: widget.campaignSlug,
      );
      if (mounted) setState(() => _campaign = campaign);
      await Future.wait([_loadCatalog(campaign.tenantId), _loadFavorites(campaign.id)]);
    } catch (_) {
      if (mounted) setState(() => _error = 'Campanha não encontrada ou indisponível.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Catálogo é conteúdo complementar aos ingressos: se a busca falhar (RLS,
  /// rede, etc.), _menu permanece null e _catalogSection() simplesmente não
  /// renderiza nada — não impede a exibição da campanha nem dos ingressos.
  Future<void> _loadCatalog(String tenantId) async {
    try {
      final menu = await _catalogRepository.fetchMenu(tenantId);
      if (mounted) setState(() => _menu = menu);
    } catch (_) {
      // silencioso — ver docstring acima.
    }
  }

  /// Favoritos são complementares: se falhar (RLS, rede, migration ausente),
  /// _favoriteCount fica null e o contador simplesmente não aparece.
  Future<void> _loadFavorites(String campaignId) async {
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final state = await _repository.getFavoriteState(campaignId: campaignId, deviceId: deviceId);
      if (mounted) setState(() { _deviceId = deviceId; _favorite = state.favorited; _favoriteCount = state.count; });
    } catch (_) {
      // silencioso — ver docstring acima.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return _errorView();

    final campaign = _campaign!;
    final activeProducts = campaign.products.where((product) => product.isActive).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _buildAppBar(),
      bottomNavigationBar: _cart.isEmpty && _catalogCart.isEmpty ? null : _cartBar(campaign),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            _hero(campaign),
            _eventInfo(campaign),
            _campaignDescription(campaign),
            _productsSection(activeProducts),
            _catalogSection(_menu),
            _trustSection(),
            _shareSection(campaign),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(children: [
        Image.asset('assets/icons/icon.png', width: 30, height: 30),
        const SizedBox(width: AppSpacing.xs),
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'Samba'),
          const TextSpan(text: 'Hub', style: TextStyle(color: AppColors.orange)),
        ])),
      ]),
      actions: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Favoritar campanha', onPressed: _toggleFavorite, icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border, color: _favorite ? AppColors.orange : null)),
          if (_favoriteCount != null) Padding(padding: const EdgeInsets.only(right: AppSpacing.xs), child: Text('$_favoriteCount', style: AppTypography.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        IconButton(tooltip: 'Compartilhar campanha', onPressed: _shareCampaign, icon: const Icon(Icons.share_outlined)),
      ],
    );
  }

  Widget _errorView() {
    return Scaffold(
      body: Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.music_off_outlined, size: 56, color: AppColors.wine),
        const SizedBox(height: AppSpacing.md),
        Text(_error!, textAlign: TextAlign.center, style: AppTypography.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Tentar novamente', onPressed: _load),
      ]))),
    );
  }

  Widget _hero(PublicCampaign campaign) {
    final image = _repository.getCoverImageUrl(campaign.coverImagePath);
    final hasImage = image != null && image.isNotEmpty;
    final vipBadge = _vipBadge(campaign);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (hasImage)
        Container(
          color: AppColors.wineDeep,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Image.network(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _heroFallback()),
            ),
          ),
        )
      else
        SizedBox(height: 240, child: _heroFallback()),
      Container(
        color: AppColors.wineDeep,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('INGRESSO ANTECIPADO · COM DESCONTO', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, letterSpacing: 1.1, fontSize: 11)),
          const SizedBox(height: AppSpacing.xs),
          Text(campaign.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.textTheme.displaySmall?.copyWith(color: AppColors.white, fontWeight: FontWeight.w800)),
          if (campaign.eventName != null) Text(campaign.eventName!, style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.darkMuted)),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(child: AppButton(label: 'Convites Vips', onPressed: _goToProducts)),
            if (vipBadge != null) ...[const SizedBox(width: AppSpacing.sm), vipBadge],
          ]),
        ]),
      ),
    ]);
  }

  Widget _heroFallback() {
    return Container(color: AppColors.wineDeep, alignment: Alignment.center, child: Stack(alignment: Alignment.center, children: [
      Icon(Icons.music_note_rounded, size: 100, color: AppColors.gold.withValues(alpha: .70)),
      Positioned(bottom: 46, child: Text('SAMBAHUB', style: AppTypography.textTheme.labelLarge?.copyWith(color: AppColors.darkMuted, letterSpacing: 4))),
    ]));
  }

  Widget _eventInfo(PublicCampaign campaign) {
    return Container(color: AppColors.paper, padding: const EdgeInsets.all(AppSpacing.md), child: Row(children: [
      const CircleAvatar(backgroundColor: AppColors.peach, child: Icon(Icons.music_note, color: AppColors.wine)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(campaign.venueName ?? 'Casa de samba', style: AppTypography.textTheme.titleMedium),
        if (campaign.startsAt != null) Text(_formatDate(campaign.startsAt!), style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      ])),
      TextButton.icon(onPressed: _shareWhatsApp, icon: const Icon(Icons.send_outlined, size: 18), label: const Text('Convidar um amigo')),
    ]));
  }

  Widget _campaignDescription(PublicCampaign campaign) {
    if (campaign.description == null || campaign.description!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0), child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sobre esta roda', style: AppTypography.textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      Text(campaign.description!, style: AppTypography.textTheme.bodyLarge),
    ])));
  }

  Widget _productsSection(List<CampaignProduct> products) {
    return Padding(key: _productsKey, padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Escolha seu jeito de chegar', style: AppTypography.textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.xs),
      Text('Evite filas, compre direto pelo celular.', style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
      const SizedBox(height: AppSpacing.md),
      if (products.isEmpty) _emptyProducts() else ...products.map(_productCard),
    ]));
  }

  Widget _emptyProducts() {
    return AppCard(child: Column(children: [const Icon(Icons.confirmation_number_outlined, size: 42, color: AppColors.muted), const SizedBox(height: AppSpacing.sm), Text('Ingressos em breve', style: AppTypography.textTheme.titleMedium), const SizedBox(height: AppSpacing.xs), const Text('A organização ainda não disponibilizou produtos para esta campanha.', textAlign: TextAlign.center)]));
  }

  Widget _productCard(CampaignProduct product) {
    final quantity = _cart[product.id] ?? 0;
    final soldOut = product.stockQuantity != null && product.stockQuantity == 0;
    return Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: AppCard(backgroundColor: quantity > 0 ? AppColors.peach : AppColors.paper, borderColor: quantity > 0 ? AppColors.orange.withValues(alpha: .55) : AppColors.line, child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.wine.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Icon(_productIcon(product.type), color: AppColors.wine)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_typeLabel(product.type), style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700)),
        Text(product.name, style: AppTypography.textTheme.titleMedium),
        if (product.description != null) Text(product.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text('R\$ ${product.price.replaceAll('.', ',')}', style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.wine, fontWeight: FontWeight.w800)),
        if (product.stockQuantity != null && !soldOut) Text('${product.stockQuantity} disponíveis', style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.muted)),
        if (soldOut) Text('Esgotado', style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
      ])),
      Column(children: [
        IconButton(onPressed: quantity == 0 ? null : () => _change(product, -1), icon: const Icon(Icons.remove_circle_outline)),
        Text('$quantity', style: AppTypography.textTheme.titleMedium),
        IconButton(onPressed: soldOut || !_canIncrease(product, quantity) ? null : () => _change(product, 1), icon: const Icon(Icons.add_circle_outline)),
      ]),
    ])));
  }

  /// Só renderiza algo se houver catálogo carregado com pelo menos uma
  /// categoria ativa contendo pelo menos um produto ativo (RLS pública já
  /// filtra is_active + campanha publicada na origem, mas o filtro aqui é
  /// defesa em profundidade, no mesmo padrão de activeProducts acima).
  Widget _catalogSection(Menu? menu) {
    if (menu == null) return const SizedBox.shrink();

    final sections = <MapEntry<CatalogCategory, List<CatalogProduct>>>[];
    for (final category in menu.categories.where((category) => category.isActive)) {
      final products = menu.productsFor(category.id).where((product) => product.isActive).toList(growable: false);
      if (products.isNotEmpty) sections.add(MapEntry(category, products));
    }
    if (sections.isEmpty) return const SizedBox.shrink();

    return Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Cardápio', style: AppTypography.textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.xs),
      Text('Peça junto com o ingresso, direto pelo celular.', style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
      const SizedBox(height: AppSpacing.md),
      for (final section in sections) ...[
        Text(section.key.name, style: AppTypography.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        ...section.value.map(_catalogProductCard),
        const SizedBox(height: AppSpacing.sm),
      ],
    ]));
  }

  Widget _catalogProductCard(CatalogProduct product) {
    final quantity = _catalogCart[product.id] ?? 0;
    final soldOut = product.stockQuantity != null && product.stockQuantity == 0;
    return Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: AppCard(backgroundColor: quantity > 0 ? AppColors.peach : AppColors.paper, borderColor: quantity > 0 ? AppColors.orange.withValues(alpha: .55) : AppColors.line, child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.wine.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.sports_bar_outlined, color: AppColors.wine)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product.name, style: AppTypography.textTheme.titleMedium),
        if (product.description != null) Text(product.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(product.formattedPrice, style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.wine, fontWeight: FontWeight.w800)),
        if (product.stockQuantity != null && !soldOut) Text('${product.stockQuantity} disponíveis', style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.muted)),
        if (soldOut) Text('Esgotado', style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
      ])),
      Column(children: [
        IconButton(onPressed: quantity == 0 ? null : () => _changeCatalog(product, -1), icon: const Icon(Icons.remove_circle_outline)),
        Text('$quantity', style: AppTypography.textTheme.titleMedium),
        IconButton(onPressed: soldOut || !_canIncreaseCatalog(product, quantity) ? null : () => _changeCatalog(product, 1), icon: const Icon(Icons.add_circle_outline)),
      ]),
    ])));
  }

  Widget _trustSection() {
    return Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0), child: AppCard(backgroundColor: AppColors.darkSurface, borderColor: AppColors.darkSurface, child: Row(children: [
      const Icon(Icons.verified_user_outlined, color: AppColors.gold),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text('Pagamento seguro e sem taxa escondida.', style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.darkMuted))),
    ])));
  }

  Widget _shareSection(PublicCampaign campaign) {
    return Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0), child: Column(children: [
      Text('Chama a galera', style: AppTypography.textTheme.titleLarge),
      const SizedBox(height: AppSpacing.xs),
      Text('Compartilhe ${campaign.name} com quem vai chegar junto.', textAlign: TextAlign.center, style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
      const SizedBox(height: AppSpacing.sm),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(onPressed: _shareCampaign, icon: const Icon(Icons.link), label: const Text('Copiar link')),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(onPressed: _shareWhatsApp, icon: const Icon(Icons.chat_bubble_outline), label: const Text('WhatsApp')),
      ]),
    ]));
  }

  Widget _cartBar(PublicCampaign campaign) {
    return SafeArea(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: AppButton(label: 'Continuar para checkout • ${_totalItems()} item(ns)', isFullWidth: true, onPressed: () => _openCheckout(campaign))));
  }

  void _goToProducts() {
    const duration = Duration(milliseconds: 350);
    final target = _productsKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: duration, curve: Curves.easeOutCubic);
      return;
    }
    // Seção ainda não construída pelo ListView: aproxima pelo offset e, ao
    // chegar, alinha exatamente na seção.
    _scrollController.animateTo(_productsOffset(), duration: duration, curve: Curves.easeOutCubic).then((_) {
      final built = _productsKey.currentContext;
      if (built != null && mounted) Scrollable.ensureVisible(built, duration: duration, curve: Curves.easeOutCubic);
    });
  }

  /// Estimativa da altura do flyer 9:16 (largura máx. 480, como no _hero()).
  double _productsOffset() {
    final width = MediaQuery.sizeOf(context).width;
    return (width > 480 ? 480.0 : width) * 16 / 9;
  }

  /// Badge de vagas VIP: "N vagas" ou "Esgotado". Null quando não há produto
  /// VIP ativo ou quando algum VIP não tem limite de estoque.
  Widget? _vipBadge(PublicCampaign campaign) {
    final vips = campaign.products.where((product) => product.isActive && product.type == 'vip').toList(growable: false);
    if (vips.isEmpty || vips.any((product) => product.stockQuantity == null)) return null;
    final remaining = vips.fold<int>(0, (total, product) => total + product.stockQuantity!);
    final soldOut = remaining == 0;
    final label = soldOut ? 'Esgotado' : '$remaining ${remaining == 1 ? 'vaga' : 'vagas'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: soldOut ? AppColors.muted : AppColors.gold, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: soldOut ? AppColors.white : AppColors.wineDeep, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
  Future<void> _toggleFavorite() async {
    final campaign = _campaign;
    if (campaign == null || _togglingFavorite) return;
    setState(() => _togglingFavorite = true);
    try {
      final deviceId = _deviceId ?? await DeviceIdService.getOrCreate();
      final state = await _repository.toggleFavorite(campaignId: campaign.id, deviceId: deviceId);
      if (!mounted) return;
      setState(() { _deviceId = deviceId; _favorite = state.favorited; _favoriteCount = state.count; });
      _showMessage(state.favorited ? 'Campanha favoritada.' : 'Campanha removida dos favoritos.');
    } catch (_) {
      if (mounted) _showMessage('Não foi possível atualizar o favorito. Tente novamente.');
    } finally {
      if (mounted) setState(() => _togglingFavorite = false);
    }
  }

  Future<void> _shareCampaign() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final payload = SharePayload(title: _campaign!.name, text: 'Confira esta roda de samba no SambaHub:', url: Uri.base.toString());
      await Clipboard.setData(ClipboardData(text: payload.content));
      if (mounted) _showMessage('Link da campanha copiado.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareWhatsApp() async {
    final uri = WhatsappService.buildCampaignUri(campaignName: _campaign!.name, campaignUrl: Uri.base.toString());
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) _showMessage('Não foi possível abrir o WhatsApp.');
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  int _totalItems() => _cart.values.fold(0, (total, quantity) => total + quantity) + _catalogCart.values.fold(0, (total, quantity) => total + quantity);
  bool _canIncrease(CampaignProduct product, int quantity) => product.stockQuantity == null || quantity < product.stockQuantity!;
  bool _canIncreaseCatalog(CatalogProduct product, int quantity) => product.stockQuantity == null || quantity < product.stockQuantity!;

  void _change(CampaignProduct product, int delta) {
    setState(() { final next = (_cart[product.id] ?? 0) + delta; if (next <= 0) _cart.remove(product.id); else _cart[product.id] = next; });
  }

  void _changeCatalog(CatalogProduct product, int delta) {
    setState(() { final next = (_catalogCart[product.id] ?? 0) + delta; if (next <= 0) _catalogCart.remove(product.id); else _catalogCart[product.id] = next; });
  }

  IconData _productIcon(String type) => switch (type) { 'combo' => Icons.restaurant_outlined, 'table' => Icons.table_restaurant_outlined, 'vip' => Icons.auto_awesome, 'courtesy' => Icons.card_giftcard_outlined, _ => Icons.confirmation_number_outlined };
  String _typeLabel(String type) => switch (type) { 'combo' => 'Mais escolhido', 'table' => 'Para chegar junto', 'vip' => 'Experiência', 'courtesy' => 'Cortesia', _ => 'Entrada' };
  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  /// Busca em campaign.products pelo id cru guardado em _cart (que nunca
  /// mistura ids de catálogo — ver changelog do topo). Null se o produto
  /// tiver saído da lista entre a seleção e o clique em "Continuar".
  CampaignProduct? _findCampaignProduct(PublicCampaign campaign, String id) {
    for (final product in campaign.products) {
      if (product.id == id) return product;
    }
    return null;
  }

  /// Mesmo padrão de busca usado em _catalogSection(): percorre as
  /// categorias do menu e usa menu.productsFor(categoryId), já que
  /// _catalogCart só guarda o id do produto, sem a categoria.
  CatalogProduct? _findCatalogProduct(Menu menu, String id) {
    for (final category in menu.categories) {
      for (final product in menu.productsFor(category.id)) {
        if (product.id == id) return product;
      }
    }
    return null;
  }

  void _openCheckout(PublicCampaign campaign) {
    final cart = ref.read(cartControllerProvider.notifier);

    for (final entry in _cart.entries) {
      final product = _findCampaignProduct(campaign, entry.key);
      if (product == null) continue;
      cart.add(CartProductRef.fromCampaignProduct(product), quantity: entry.value);
    }

    final menu = _menu;
    if (menu != null) {
      for (final entry in _catalogCart.entries) {
        final product = _findCatalogProduct(menu, entry.key);
        if (product == null) continue;
        cart.add(CartProductRef.fromCatalogProduct(product), quantity: entry.value);
      }
    }

    context.go('/checkout?campaign=${campaign.id}');
  }
}