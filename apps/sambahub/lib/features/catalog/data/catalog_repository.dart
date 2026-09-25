// CHANGELOG
// 2026-09-18: Item 1 (Catalog) — completado o repository.
// - Adicionados: updateCategory(), deleteCategory(), updateProduct(),
//   setProductActive().
// - deleteProduct() agora exige tenantId (filtro por tenant_id) e confirma que
//   alguma linha foi afetada. Com RLS, UPDATE/DELETE sem permissão não gera erro
//   e afeta 0 linhas; por isso as mutações usam .select('id') para detectar isso.
// - Exclusão física (decisão do usuário): a FK (tenant_id, category_id) é
//   ON DELETE RESTRICT, então excluir categoria com produtos falha com 23503;
//   o erro é traduzido para mensagem compreensível.
// - createCategory(): slug vazio (ex.: nome só com símbolos) violaria o check
//   catalog_categories.slug; agora é validado antes do insert.
// - Adicionada CatalogException (mensagem já pronta para exibição) e tradução
//   dos códigos Postgres 23505 (duplicidade), 23503 (FK) e 23514 (check).
// - fetchMenu() e createProduct() sem alteração de lógica.
// - Assinaturas alteradas: deleteProduct(productId) -> deleteProduct(productId,
//   {tenantId}); o catalog_controller.dart deve ser atualizado em seguida.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/catalog_category.dart';
import '../domain/catalog_product.dart';
import '../domain/menu.dart';

/// Erro de negócio/persistência do catálogo; [message] já é exibível ao usuário.
final class CatalogException implements Exception {
  const CatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CatalogRepository {
  CatalogRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  Future<Menu> fetchMenu(String tenantId) async {
    final categories = await _client
        .from('catalog_categories')
        .select()
        .eq('tenant_id', tenantId)
        .order('sort_order');
    final products = await _client
        .from('catalog_products')
        .select()
        .eq('tenant_id', tenantId)
        .order('name');
    return Menu(
      tenantId: tenantId,
      categories:
          categories.map(CatalogCategory.fromMap).toList(growable: false),
      products: products.map(CatalogProduct.fromMap).toList(growable: false),
    );
  }

  Future<CatalogCategory> createCategory({
    required String tenantId,
    required String name,
  }) async {
    final slug = _slugify(name);
    if (slug.isEmpty) {
      throw const CatalogException(
          'Informe um nome com letras ou números para a categoria.');
    }
    try {
      final row = await _client
          .from('catalog_categories')
          .insert({
            'tenant_id': tenantId,
            'name': name.trim(),
            'slug': slug,
          })
          .select()
          .single();
      return CatalogCategory.fromMap(row);
    } on PostgrestException catch (error) {
      throw _translate(error, duplicate: 'Já existe uma categoria com esse nome.');
    }
  }

  Future<void> updateCategory({
    required String tenantId,
    required String id,
    required String name,
    String? description,
    required int sortOrder,
    required bool isActive,
  }) async {
    try {
      final rows = await _client
          .from('catalog_categories')
          .update({
            'name': name.trim(),
            'description': _nullIfBlank(description),
            'sort_order': sortOrder,
            'is_active': isActive,
          })
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .select('id');
      _ensureAffected(rows, 'categoria');
    } on PostgrestException catch (error) {
      throw _translate(error, duplicate: 'Já existe uma categoria com esse nome.');
    }
  }

  Future<void> deleteCategory({
    required String tenantId,
    required String id,
  }) async {
    try {
      final rows = await _client
          .from('catalog_categories')
          .delete()
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .select('id');
      _ensureAffected(rows, 'categoria');
    } on PostgrestException catch (error) {
      throw _translate(
        error,
        foreignKey:
            'Esta categoria ainda possui produtos. Exclua os produtos antes de excluir a categoria.',
      );
    }
  }

  Future<CatalogProduct> createProduct({
    required String tenantId,
    required String categoryId,
    required String name,
    required int priceCents,
  }) async {
    try {
      final row = await _client
          .from('catalog_products')
          .insert({
            'tenant_id': tenantId,
            'category_id': categoryId,
            'name': name.trim(),
            'price': _decimalPrice(priceCents),
          })
          .select()
          .single();
      return CatalogProduct.fromMap(row);
    } on PostgrestException catch (error) {
      throw _translate(
        error,
        duplicate: 'Já existe um produto com esse nome nesta categoria.',
      );
    }
  }

  /// [stockQuantity] nulo significa estoque não controlado (coluna aceita null).
  Future<void> updateProduct({
    required String tenantId,
    required String id,
    required String name,
    required int priceCents,
    String? description,
    int? stockQuantity,
    required bool isActive,
  }) async {
    try {
      final rows = await _client
          .from('catalog_products')
          .update({
            'name': name.trim(),
            'price': _decimalPrice(priceCents),
            'description': _nullIfBlank(description),
            'stock_quantity': stockQuantity,
            'is_active': isActive,
          })
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .select('id');
      _ensureAffected(rows, 'produto');
    } on PostgrestException catch (error) {
      throw _translate(
        error,
        duplicate: 'Já existe um produto com esse nome nesta categoria.',
      );
    }
  }

  Future<void> setProductActive({
    required String tenantId,
    required String id,
    required bool isActive,
  }) async {
    try {
      final rows = await _client
          .from('catalog_products')
          .update({'is_active': isActive})
          .eq('tenant_id', tenantId)
          .eq('id', id)
          .select('id');
      _ensureAffected(rows, 'produto');
    } on PostgrestException catch (error) {
      throw _translate(error);
    }
  }

  Future<void> deleteProduct(
    String productId, {
    required String tenantId,
  }) async {
    try {
      final rows = await _client
          .from('catalog_products')
          .delete()
          .eq('tenant_id', tenantId)
          .eq('id', productId)
          .select('id');
      _ensureAffected(rows, 'produto');
    } on PostgrestException catch (error) {
      throw _translate(
        error,
        foreignKey: 'Este produto está em uso e não pode ser excluído.',
      );
    }
  }

  void _ensureAffected(List<dynamic> rows, String label) {
    if (rows.isEmpty) {
      throw CatalogException(
          'Não foi possível alterar o(a) $label: item não encontrado ou sem permissão.');
    }
  }

  CatalogException _translate(
    PostgrestException error, {
    String? duplicate,
    String? foreignKey,
  }) {
    switch (error.code) {
      case '23505':
        return CatalogException(duplicate ?? 'Já existe um registro igual a este.');
      case '23503':
        return CatalogException(
            foreignKey ?? 'Operação bloqueada por registros relacionados.');
      case '23514':
        return const CatalogException(
            'Dados inválidos: verifique nome, preço e estoque.');
      case '42501':
        return const CatalogException(
            'Você não tem permissão para realizar esta operação.');
      default:
        return CatalogException('Erro ao salvar no servidor: ${error.message}');
    }
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _decimalPrice(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents.abs() % 100).toString().padLeft(2, '0');
    return '$reais.$centavos';
  }
}