class SambaGroup {
  const SambaGroup({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.slug,
    this.description,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.isActive = true,
  });

  final String id;
  final String tenantId;
  final String name;
  final String slug;
  final String? description;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final bool isActive;

  factory SambaGroup.fromMap(Map<String, dynamic> map) {
    return SambaGroup(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      contactName: map['contact_name'] as String?,
      contactEmail: map['contact_email'] as String?,
      contactPhone: map['contact_phone'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertMap({required String tenantId}) {
    return {
      'tenant_id': tenantId,
      'name': name,
      'slug': slug,
      'description': description,
      'contact_name': contactName,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'is_active': isActive,
    };
  }
}
