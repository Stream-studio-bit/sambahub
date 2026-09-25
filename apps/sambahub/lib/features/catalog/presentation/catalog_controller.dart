// CHANGELOG
// 2026-09-18: Item 1 (Catalog) — completado o controller.
// - Adicionados: editCategory(), removeCategory(), editProduct(),
//   setProductActive().
// - removeProduct() agora repassa tenantId ao repository (filtro por tenant).
// - Mutações não trocam mais o state por AsyncLoading: antes, qualquer operação
//   substituía a tela inteira por um spinner e, em caso de falha, o cardápio era
//   trocado pela mensagem de erro. Agora o state permanece com os dados atuais,
//   a exceção (CatalogException com mensagem pronta) é propagada para a página
//   exibir o feedback, e após sucesso o menu é recarregado do banco.
// - O indicador de loading durante a operação fica a cargo da página.
// - build(), providers e nomes existentes (addCategory, addProduct,
//   removeProduct) preservados.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_repository.dart';
import '../domain/menu.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository();
});

final catalogControllerProvider =
    AsyncNotifierProvider.family<CatalogController, Menu, String>(
        CatalogController.new);

class CatalogController extends FamilyAsyncNotifier<Menu, String> {
  late CatalogRepository _repository;

  @override
  Future<Menu> build(String tenantId) async {
    _repository = ref.read(catalogRepositoryProvider);
    return _repository.fetchMenu(tenantId);
  }

  /// Executa a mutação; se falhar, a exceção sobe para a página e o state
  /// atual é mantido. Se der certo, recarrega o menu.
  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    state = AsyncData(await _repository.fetchMenu(arg));
  }

  Future<void> addCategory(String name) {
    return _mutate(
        () => _repository.createCategory(tenantId: arg, name: name));
  }

  Future<void> editCategory({
    required String id,
    required String name,
    String? description,
    required int sortOrder,
    required bool isActive,
  }) {
    return _mutate(() => _repository.updateCategory(
          tenantId: arg,
          id: id,
          name: name,
          description: description,
          sortOrder: sortOrder,
          isActive: isActive,
        ));
  }

  Future<void> removeCategory(String id) {
    return _mutate(() => _repository.deleteCategory(tenantId: arg, id: id));
  }

  Future<void> addProduct(
      {required String categoryId,
      required String name,
      required int priceCents}) {
    return _mutate(() => _repository.createProduct(
        tenantId: arg,
        categoryId: categoryId,
        name: name,
        priceCents: priceCents));
  }

  Future<void> editProduct({
    required String id,
    required String name,
    required int priceCents,
    String? description,
    int? stockQuantity,
    required bool isActive,
  }) {
    return _mutate(() => _repository.updateProduct(
          tenantId: arg,
          id: id,
          name: name,
          priceCents: priceCents,
          description: description,
          stockQuantity: stockQuantity,
          isActive: isActive,
        ));
  }

  Future<void> setProductActive(String id, {required bool isActive}) {
    return _mutate(() => _repository.setProductActive(
        tenantId: arg, id: id, isActive: isActive));
  }

  Future<void> removeProduct(String productId) {
    return _mutate(
        () => _repository.deleteProduct(productId, tenantId: arg));
  }
}