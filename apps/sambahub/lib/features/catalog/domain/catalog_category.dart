class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String name;
  final String slug;
  final String? description;
  final int sortOrder;
  final bool isActive;

  factory CatalogCategory.fromMap(Map<String, dynamic> map) {
    return CatalogCategory(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
