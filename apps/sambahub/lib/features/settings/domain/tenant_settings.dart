class TenantSettings {
  const TenantSettings({
    required this.tenantId,
    required this.name,
    required this.slug,
    required this.status,
    this.legalName,
    this.email,
    this.phone,
    this.timezone = 'America/Sao_Paulo',
    this.currency = 'BRL',
    this.notificationsEnabled = true,
    this.checkinEnabled = true,
    this.settings = const {},
  });

  final String tenantId;
  final String name;
  final String slug;
  final String status;
  final String? legalName;
  final String? email;
  final String? phone;
  final String timezone;
  final String currency;
  final bool notificationsEnabled;
  final bool checkinEnabled;
  final Map<String, dynamic> settings;

  factory TenantSettings.fromMap(Map<String, dynamic> map) {
    return TenantSettings(
      tenantId: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      status: map['status'] as String,
      legalName: map['legal_name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      timezone: map['timezone'] as String? ?? 'America/Sao_Paulo',
      currency: map['currency'] as String? ?? 'BRL',
      notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
      checkinEnabled: map['checkin_enabled'] as bool? ?? true,
      settings: Map<String, dynamic>.from(map['settings'] as Map? ?? const {}),
    );
  }
}
