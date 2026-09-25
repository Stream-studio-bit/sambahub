class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;

  String get displayName =>
      name?.trim().isNotEmpty == true ? name!.trim() : email;

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
