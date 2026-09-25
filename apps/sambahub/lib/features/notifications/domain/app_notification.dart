class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.tenantId,
    this.readAt,
    this.actionRoute,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? tenantId;
  final DateTime? readAt;
  final String? actionRoute;
  final Map<String, dynamic> metadata;

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] as String,
      createdAt: DateTime.parse(map['created_at'].toString()),
      tenantId: map['tenant_id'] as String?,
      readAt: map['read_at'] == null
          ? null
          : DateTime.tryParse(map['read_at'].toString()),
      actionRoute: map['action_route'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }
}
