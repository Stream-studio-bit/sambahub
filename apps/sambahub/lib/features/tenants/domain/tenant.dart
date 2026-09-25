class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.role,
    this.legalName,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final String slug;
  final String status;
  final String role;
  final String? legalName;
  final String? email;
  final String? phone;

  bool get isActive => status == 'active';

  factory Tenant.fromMembershipMap(Map<String, dynamic> map) {
    final tenantMap = Map<String, dynamic>.from(
      (map['tenants'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    return Tenant(
      id: tenantMap['id'] as String? ?? map['tenant_id'] as String,
      name: tenantMap['name'] as String? ?? 'Organização sem nome',
      slug: tenantMap['slug'] as String? ?? '',
      status: tenantMap['status'] as String? ?? 'active',
      role: map['role'] as String? ?? 'viewer',
      legalName: tenantMap['legal_name'] as String?,
      email: tenantMap['email'] as String?,
      phone: tenantMap['phone'] as String?,
    );
  }
}
