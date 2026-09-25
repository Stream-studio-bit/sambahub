class TenantContext {
  const TenantContext({
    required this.tenantId,
    required this.name,
    required this.slug,
    required this.role,
  });

  final String tenantId;
  final String name;
  final String slug;
  final String role;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get canManageMembers => isAdmin;
  bool get canManageFinance => isAdmin || role == 'finance';
  bool get canCheckIn => isAdmin || role == 'checkin';
  bool get canManageGroups => isAdmin || role == 'group_manager';
  bool get canViewOnly => role == 'viewer';

  factory TenantContext.fromMap(Map<String, dynamic> map) {
    return TenantContext(
      tenantId: map['tenant_id'] as String? ?? map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      role: map['role'] as String? ?? 'viewer',
    );
  }
}
