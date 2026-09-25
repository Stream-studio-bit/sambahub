class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.tenantId,
    required this.categoryId,
    required this.name,
    required this.priceCents,
    this.description,
    this.imagePath,
    this.stockQuantity,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String categoryId;
  final String name;
  final int priceCents;
  final String? description;
  final String? imagePath;
  final int? stockQuantity;
  final bool isActive;

  String get formattedPrice {
    final absolute = priceCents.abs();
    final reais = absolute ~/ 100;
    final centavos = (absolute % 100).toString().padLeft(2, '0');
    final prefix = priceCents < 0 ? '-' : '';
    return 'R\$ $prefix$reais,$centavos';
  }

  factory CatalogProduct.fromMap(Map<String, dynamic> map) {
    return CatalogProduct(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      priceCents: _parseCents(map['price']),
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
      stockQuantity: map['stock_quantity'] as int?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  static int _parseCents(Object? value) {
    if (value is int) return value;
    final raw = value?.toString().trim() ?? '0';
    final normalized =
        raw.contains(',') ? raw.replaceAll('.', '').replaceAll(',', '.') : raw;
    final parts = normalized.split('.');
    final reais =
        int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
    final decimal =
        parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '0';
    final padded = decimal.padRight(2, '0');
    final centavos = int.tryParse(padded.substring(0, 2)) ?? 0;
    return reais * 100 + centavos;
  }
}
