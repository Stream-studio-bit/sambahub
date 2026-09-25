import 'catalog_category.dart';
import 'catalog_product.dart';

class Menu {
  const Menu({
    required this.tenantId,
    required this.categories,
    required this.products,
  });

  final String tenantId;
  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;

  List<CatalogProduct> productsFor(String categoryId) {
    return products
        .where((product) => product.categoryId == categoryId)
        .toList(growable: false);
  }
}
