// catalog_page.dart
//
// CHANGELOG
// 2026-09-19 — Trilha B, P4
//   - Categoria: edição completa (nome, descrição, ordem, ativa) via diálogo
//     ao tocar no card; exclusão com confirmação (bloqueio por FK quando há
//     produtos vem pronto do repository via CatalogException).
//   - Produto: edição completa (nome, preço, descrição, estoque — campo
//     vazio = sem controle de estoque —, ativo) via diálogo ao tocar na
//     linha; alternância ativo/inativo direto na linha (switch), com marca
//     "Inativo"; exclusão com confirmação.
//   - SnackBar de sucesso após criar/editar/excluir categoria ou produto.
//   - Como o controller não usa mais AsyncLoading nas mutações
//     (catalog_controller.dart, item 1), a página agora controla o estado
//     "ocupado" (_busy): ações ficam desabilitadas e uma barra de progresso
//     aparece no topo durante qualquer mutação; cada ação roda em
//     try/catch, mostrando CatalogException.message (ou mensagem genérica)
//     em SnackBar de erro.
//   - error: do .when agora mostra mensagem e botão "Tentar novamente"
//     (reinvoca o provider) em vez de texto fixo sem ação.
//   - Validação de limites do banco antes de chamar o controller (nome de
//     categoria 1–120, de produto 1–160, preço >= 0, estoque nulo ou >= 0);
//     inválido não submete, mostra SnackBar explicando.
//   - Sem campos novos. Upload de imagem do produto continua fora do
//     escopo (sem esse fluxo no catálogo).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../data/catalog_repository.dart' show CatalogException;
import '../domain/catalog_category.dart';
import '../domain/catalog_product.dart';
import '../presentation/catalog_controller.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({required this.tenantId, super.key});

  final String tenantId;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  bool _busy = false;

  String get _tenantId => widget.tenantId;

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(catalogControllerProvider(_tenantId));
    return Scaffold(
      appBar: AppBar(title: const Text('Cardápio'), actions: [
        IconButton(
            onPressed: _busy
                ? null
                : () => ref.invalidate(catalogControllerProvider(_tenantId)),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar cardápio')
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : () => _showCategoryCreateDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Categoria')),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
            child: menu.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
              onRetry: () =>
                  ref.invalidate(catalogControllerProvider(_tenantId))),
          data: (value) => RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(catalogControllerProvider(_tenantId).future),
              child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text('Produtos e categorias',
                        style: AppTypography.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Organize o que sua roda oferece ao público.',
                        style: AppTypography.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted)),
                    const SizedBox(height: AppSpacing.xl),
                    if (value.categories.isEmpty)
                      const AppCard(
                          child: Text(
                              'Crie a primeira categoria para começar o cardápio.'))
                    else
                      ...value.categories.map((category) {
                        final products = value.productsFor(category.id);
                        return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AppCard(
                                semanticLabel: 'Categoria ${category.name}',
                                onTap: _busy
                                    ? null
                                    : () => _showCategoryEditDialog(
                                        context, category),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(category.name,
                                            style: AppTypography
                                                .textTheme.titleLarge)),
                                    Text('${products.length} itens',
                                        style:
                                            AppTypography.textTheme.bodySmall),
                                    IconButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _confirmDeleteCategory(
                                                context, category),
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppColors.error),
                                        tooltip: 'Excluir categoria')
                                  ]),
                                  if (!category.isActive)
                                    const _InactiveBadge(),
                                  if (category.description != null)
                                    Text(category.description!,
                                        style:
                                            AppTypography.textTheme.bodySmall),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (products.isEmpty)
                                    Text('Nenhum produto nesta categoria.',
                                        style:
                                            AppTypography.textTheme.bodySmall)
                                  else
                                    ...products.map((product) => _ProductRow(
                                        product: product,
                                        busy: _busy,
                                        onTap: () => _showProductEditDialog(
                                            context, product),
                                        onToggleActive: (isActive) =>
                                            _toggleProductActive(
                                                product, isActive),
                                        onDelete: () => _confirmDeleteProduct(
                                            context, product))),
                                  const SizedBox(height: AppSpacing.sm),
                                  AppButton(
                                      label: 'Adicionar produto',
                                      variant: AppButtonVariant.outline,
                                      size: AppButtonSize.small,
                                      onPressed: _busy
                                          ? null
                                          : () => _showProductCreateDialog(
                                              context, category.id))
                                ])));
                      })
                  ])),
        ))
      ]),
    );
  }

  // ---- execução de mutações (estado ocupado + feedback) ----

  Future<void> _runMutation(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } on CatalogException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: AppColors.error));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Não foi possível concluir a operação. Tente novamente.'),
          backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleProductActive(CatalogProduct product, bool isActive) {
    return _runMutation(
        () => ref
            .read(catalogControllerProvider(_tenantId).notifier)
            .setProductActive(product.id, isActive: isActive),
        successMessage:
            isActive ? 'Produto ativado.' : 'Produto marcado como inativo.');
  }

  Future<void> _confirmDeleteCategory(
      BuildContext context, CatalogCategory category) async {
    final confirmed = await _confirmDialog(context,
        title: 'Excluir categoria',
        message:
            'Excluir "${category.name}"? Categorias com produtos não podem ser excluídas.');
    if (confirmed != true) return;
    await _runMutation(
        () => ref
            .read(catalogControllerProvider(_tenantId).notifier)
            .removeCategory(category.id),
        successMessage: 'Categoria excluída.');
  }

  Future<void> _confirmDeleteProduct(
      BuildContext context, CatalogProduct product) async {
    final confirmed = await _confirmDialog(context,
        title: 'Excluir produto', message: 'Excluir "${product.name}"?');
    if (confirmed != true) return;
    await _runMutation(
        () => ref
            .read(catalogControllerProvider(_tenantId).notifier)
            .removeProduct(product.id),
        successMessage: 'Produto excluído.');
  }

  Future<bool?> _confirmDialog(BuildContext context,
      {required String title, required String message}) {
    return showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar')),
                  AppButton(
                      label: 'Excluir',
                      size: AppButtonSize.small,
                      onPressed: () => Navigator.pop(dialogContext, true))
                ]));
  }

  void _showValidationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- diálogos de categoria ----

  Future<void> _showCategoryCreateDialog(BuildContext context) async {
    final name = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Nova categoria'),
                content: AppInput(
                    label: 'Nome',
                    controller: name,
                    hintText: 'Ex.: Bebidas'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar')),
                  AppButton(
                      label: 'Criar',
                      size: AppButtonSize.small,
                      onPressed: () {
                        final trimmed = name.text.trim();
                        if (trimmed.isEmpty || trimmed.length > 120) {
                          _showValidationError(context,
                              'Nome da categoria deve ter entre 1 e 120 caracteres.');
                          return;
                        }
                        Navigator.pop(dialogContext);
                        _runMutation(
                            () => ref
                                .read(catalogControllerProvider(_tenantId)
                                    .notifier)
                                .addCategory(trimmed),
                            successMessage: 'Categoria criada.');
                      })
                ]));
    name.dispose();
  }

  Future<void> _showCategoryEditDialog(
      BuildContext context, CatalogCategory category) async {
    final name = TextEditingController(text: category.name);
    final description = TextEditingController(text: category.description ?? '');
    final sortOrder =
        TextEditingController(text: category.sortOrder.toString());
    var isActive = category.isActive;

    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
                    title: const Text('Editar categoria'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          AppInput(label: 'Nome', controller: name),
                          const SizedBox(height: AppSpacing.sm),
                          AppInput(
                              label: 'Descrição',
                              controller: description,
                              hintText: 'Opcional'),
                          const SizedBox(height: AppSpacing.sm),
                          AppInput(
                              label: 'Ordem',
                              controller: sortOrder,
                              keyboardType: TextInputType.number),
                          const SizedBox(height: AppSpacing.sm),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Ativa'),
                              value: isActive,
                              onChanged: (value) =>
                                  setDialogState(() => isActive = value))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar')),
                      AppButton(
                          label: 'Salvar',
                          size: AppButtonSize.small,
                          onPressed: () {
                            final trimmedName = name.text.trim();
                            final order = int.tryParse(sortOrder.text.trim());
                            if (trimmedName.isEmpty ||
                                trimmedName.length > 120) {
                              _showValidationError(context,
                                  'Nome da categoria deve ter entre 1 e 120 caracteres.');
                              return;
                            }
                            if (order == null) {
                              _showValidationError(
                                  context, 'Ordem inválida.');
                              return;
                            }
                            Navigator.pop(dialogContext);
                            _runMutation(
                                () => ref
                                    .read(catalogControllerProvider(_tenantId)
                                        .notifier)
                                    .editCategory(
                                        id: category.id,
                                        name: trimmedName,
                                        description: description.text,
                                        sortOrder: order,
                                        isActive: isActive),
                                successMessage: 'Categoria atualizada.');
                          })
                    ])));
    name.dispose();
    description.dispose();
    sortOrder.dispose();
  }

  // ---- diálogos de produto ----

  Future<void> _showProductCreateDialog(
      BuildContext context, String categoryId) async {
    final name = TextEditingController();
    final price = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Novo produto'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  AppInput(
                      label: 'Nome',
                      controller: name,
                      hintText: 'Ex.: Caipirinha'),
                  const SizedBox(height: AppSpacing.sm),
                  AppInput(
                      label: 'Preço',
                      controller: price,
                      hintText: 'Ex.: 18,00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar')),
                  AppButton(
                      label: 'Criar',
                      size: AppButtonSize.small,
                      onPressed: () {
                        final trimmedName = name.text.trim();
                        final cents = _parseCents(price.text);
                        if (trimmedName.isEmpty || trimmedName.length > 160) {
                          _showValidationError(context,
                              'Nome do produto deve ter entre 1 e 160 caracteres.');
                          return;
                        }
                        if (cents < 0) {
                          _showValidationError(
                              context, 'Preço inválido.');
                          return;
                        }
                        Navigator.pop(dialogContext);
                        _runMutation(
                            () => ref
                                .read(catalogControllerProvider(_tenantId)
                                    .notifier)
                                .addProduct(
                                    categoryId: categoryId,
                                    name: trimmedName,
                                    priceCents: cents),
                            successMessage: 'Produto criado.');
                      })
                ]));
    name.dispose();
    price.dispose();
  }

  Future<void> _showProductEditDialog(
      BuildContext context, CatalogProduct product) async {
    final name = TextEditingController(text: product.name);
    final price =
        TextEditingController(text: _centsToInput(product.priceCents));
    final description =
        TextEditingController(text: product.description ?? '');
    final stock =
        TextEditingController(text: product.stockQuantity?.toString() ?? '');
    var isActive = product.isActive;

    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
                    title: const Text('Editar produto'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          AppInput(label: 'Nome', controller: name),
                          const SizedBox(height: AppSpacing.sm),
                          AppInput(
                              label: 'Preço',
                              controller: price,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true)),
                          const SizedBox(height: AppSpacing.sm),
                          AppInput(
                              label: 'Descrição',
                              controller: description,
                              hintText: 'Opcional'),
                          const SizedBox(height: AppSpacing.sm),
                          AppInput(
                              label: 'Estoque',
                              controller: stock,
                              hintText: 'Vazio = sem controle de estoque',
                              keyboardType: TextInputType.number),
                          const SizedBox(height: AppSpacing.sm),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Ativo'),
                              value: isActive,
                              onChanged: (value) =>
                                  setDialogState(() => isActive = value))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar')),
                      AppButton(
                          label: 'Salvar',
                          size: AppButtonSize.small,
                          onPressed: () {
                            final trimmedName = name.text.trim();
                            final cents = _parseCents(price.text);
                            final trimmedStock = stock.text.trim();
                            final stockQuantity = trimmedStock.isEmpty
                                ? null
                                : int.tryParse(trimmedStock);
                            if (trimmedName.isEmpty ||
                                trimmedName.length > 160) {
                              _showValidationError(context,
                                  'Nome do produto deve ter entre 1 e 160 caracteres.');
                              return;
                            }
                            if (cents < 0) {
                              _showValidationError(
                                  context, 'Preço inválido.');
                              return;
                            }
                            if (trimmedStock.isNotEmpty &&
                                (stockQuantity == null ||
                                    stockQuantity < 0)) {
                              _showValidationError(context,
                                  'Estoque deve ser vazio (sem controle) ou um número maior ou igual a zero.');
                              return;
                            }
                            Navigator.pop(dialogContext);
                            _runMutation(
                                () => ref
                                    .read(catalogControllerProvider(_tenantId)
                                        .notifier)
                                    .editProduct(
                                        id: product.id,
                                        name: trimmedName,
                                        priceCents: cents,
                                        description: description.text,
                                        stockQuantity: stockQuantity,
                                        isActive: isActive),
                                successMessage: 'Produto atualizado.');
                          })
                    ])));
    name.dispose();
    price.dispose();
    description.dispose();
    stock.dispose();
  }

  int _parseCents(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    if (normalized.isEmpty) return -1;
    final parts = normalized.split('.');
    final reais = int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9]'), ''));
    if (reais == null) return -1;
    final cents = parts.length > 1
        ? int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0
        : 0;
    return reais * 100 + cents;
  }

  String _centsToInput(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '$reais,$centavos';
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.busy,
    required this.onTap,
    required this.onToggleActive,
    required this.onDelete,
  });

  final CatalogProduct product;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: busy ? null : onTap,
      title: Row(children: [
        Expanded(child: Text(product.name)),
        if (!product.isActive) const _InactiveBadge()
      ]),
      subtitle: Text(product.formattedPrice),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(
            value: product.isActive,
            onChanged: busy ? null : onToggleActive),
        IconButton(
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Excluir produto')
      ]));
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text('Inativo',
          style: AppTypography.textTheme.bodySmall
              ?.copyWith(color: AppColors.error)));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Não foi possível carregar o cardápio.',
                style: AppTypography.textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
                label: 'Tentar novamente',
                size: AppButtonSize.small,
                onPressed: onRetry)
          ])));
}