// CHANGELOG
// 2026-09-20: Adicionado vipQuantity (events.vip_quantity, migration
// 2026_09_20_events_vip_quantity.sql): número de convites VIP gratuitos
// configurado no evento. Usado na criação da campanha para gerar o produto
// VIP. Campo opcional; nenhuma outra lógica alterada.
// 2026-09-19: P10 (Trilha G) — criado o model SambaEvent (lib/features/events/
// domain/event.dart). Motivo: o módulo de eventos só tinha repository e
// formulário, sem model tipado para listagem/edição. Usa apenas colunas
// existentes de public.events (migration 20260915000007) e o join com venues
// (name, city). Sem campos novos. Status: draft, published, cancelled, finished.

class SambaEvent {
  const SambaEvent({
    required this.id,
    required this.tenantId,
    required this.venueId,
    required this.name,
    required this.slug,
    required this.status,
    required this.startsAt,
    this.groupId,
    this.description,
    this.coverImagePath,
    this.endsAt,
    this.capacity,
    this.vipQuantity,
    this.publishedAt,
    this.venueName,
    this.venueCity,
  });

  final String id;
  final String tenantId;
  final String? groupId;
  final String venueId;
  final String name;
  final String slug;
  final String? description;

  /// Caminho no bucket event-covers (nunca URL permanente).
  final String? coverImagePath;
  final String status;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? capacity;
  final int? vipQuantity;
  final DateTime? publishedAt;

  // Vêm do join venues(name, city).
  final String? venueName;
  final String? venueCity;

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isCancelled => status == 'cancelled';
  bool get isFinished => status == 'finished';

  factory SambaEvent.fromMap(Map<String, dynamic> map) {
    final venue = map['venues'];
    final venueMap = venue is Map<String, dynamic> ? venue : null;
    return SambaEvent(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      groupId: map['group_id'] as String?,
      venueId: map['venue_id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      status: map['status'] as String? ?? 'draft',
      startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
      endsAt: _parseDate(map['ends_at']),
      capacity: (map['capacity'] as num?)?.toInt(),
      vipQuantity: (map['vip_quantity'] as num?)?.toInt(),
      publishedAt: _parseDate(map['published_at']),
      venueName: venueMap?['name'] as String?,
      venueCity: venueMap?['city'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;
}