// CHANGELOG
// 2026-09-19 — P7 / Trilha E (Membros)
// - Removidos `invitedAt` e `joinedAt`: nenhuma das duas colunas existe em
//   tenant_memberships (confirmado em 20260915000004_create_tenant_
//   memberships.sql — só id, tenant_id, user_id, role, status, created_at,
//   updated_at). Os dois campos sempre vinham null do banco; não eram bug em
//   runtime porque o código já tratava null, mas eram informação inexistente
//   sendo carregada como se fosse real.
// - Mantidos role/status como String livre (validados pela UI contra a lista
//   fixa do prompt mestre, que bate com o CHECK da coluna:
//   owner/admin/producer/finance/checkin/group_manager/viewer e
//   active/invited/suspended).

class TenantMember {
  const TenantMember({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.name,
    this.email,
  });

  final String id;
  final String tenantId;
  final String userId;
  final String role;
  final String status;
  final DateTime createdAt;
  final String? name;
  final String? email;

  bool get isActive => status == 'active';
  bool get isOwner => role == 'owner';

  factory TenantMember.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return TenantMember(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'].toString()),
      name: profile?['name'] as String?,
      email: profile?['email'] as String?,
    );
  }
}