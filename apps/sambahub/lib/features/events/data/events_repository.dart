// CHANGELOG
// 2026-09-20: Convites VIP no evento. _eventColumns inclui vip_quantity e
// createEvent ganhou o parâmetro opcional vipQuantity (grava
// events.vip_quantity). updateEvent NÃO foi alterado: a quantidade de VIP só
// é definida na criação; depois de a campanha existir, o estoque do produto
// VIP é editado no detalhe da campanha. Nenhuma outra lógica alterada.
// 2026-09-19: P10 (Trilha G) — repository completo de eventos.
// - Novo: listEvents (com join venues(name, city), ignora deleted_at).
// - Novo: updateEvent (nome, descrição, início/fim, capacidade, local). O slug
//   NÃO muda na edição (é o link público). Só edita eventos draft/published.
// - Novo: publishEvent (draft → published, grava published_at), cancelEvent
//   (draft|published → cancelled) e finishEvent (published → finished).
//   Transições validadas na própria query (filtro por status de origem).
// - Padrão de repository do projeto: .eq('tenant_id') em toda mutação,
//   .select('id') no fim do UPDATE e erro se voltar vazio (RLS afeta 0 linhas
//   sem gerar erro), tradução dos códigos Postgres 23505, 23503, 23514, 42501
//   para EventsException (mensagem em português).
// - uploadCoverImage: agora o UPDATE de cover_image_path filtra por tenant_id,
//   usa .select('id') e falha se afetar 0 linhas; extensão restrita a
//   jpg/jpeg/png/webp/heic; remove (melhor esforço) o arquivo antigo se a
//   extensão mudou. Continua salvando só o path na coluna.
// - createEvent: novo parâmetro opcional endsAt (grava ends_at), usado pelo
//   formulário de evento. Fora isso, mesmo comportamento; a busca/criação do local foi extraída
//   para _resolveVenueId (reutilizada por updateEvent). ensureWorkspace e
//   getCoverImageUrl não foram alterados.

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/event.dart';

/// Erro de negócio/banco com mensagem pronta para exibir ao usuário.
final class EventsException implements Exception {
  const EventsException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class EventsRepository {
  EventsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  final SupabaseClient _client;

  static const _coverBucket = 'event-covers';
  static const _coverExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const _eventColumns =
      'id, tenant_id, group_id, venue_id, name, slug, description, '
      'cover_image_path, status, starts_at, ends_at, capacity, vip_quantity, '
      'published_at, '
      'venues(name, city)';

  Future<String> ensureWorkspace(
      {required String name, required String profileType}) async {
    final response = await _client.functions.invoke('provision-workspace',
        body: {'name': name, 'profile_type': profileType});
    final data = response.data;
    if (data is! Map<String, dynamic> || data['data'] is! Map<String, dynamic>)
      throw const FormatException(
          'Resposta inválida ao preparar a organização.');
    return (data['data'] as Map<String, dynamic>)['tenant_id'] as String;
  }

  Future<List<SambaEvent>> listEvents(String tenantId) async {
    try {
      final rows = await _client
          .from('events')
          .select(_eventColumns)
          .eq('tenant_id', tenantId)
          .isFilter('deleted_at', null)
          .order('starts_at', ascending: false);
      return rows.map(SambaEvent.fromMap).toList();
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  Future<Map<String, dynamic>> createEvent({
    required String tenantId,
    required String name,
    required String slug,
    required DateTime startsAt,
    required String venueName,
    required String address,
    required String city,
    required String state,
    required String postalCode,
    String? description,
    DateTime? endsAt,
    int? capacity,
    int? vipQuantity,
    String? groupId,
  }) async {
    try {
      final venueId = await _resolveVenueId(
        tenantId: tenantId,
        venueName: venueName,
        address: address,
        city: city,
        state: state,
        postalCode: postalCode,
      );

      final event = await _client
          .from('events')
          .insert({
            'tenant_id': tenantId,
            'group_id': groupId,
            'venue_id': venueId,
            'name': name.trim(),
            'slug': _slug(slug),
            'description': _nullable(description),
            'status': 'draft',
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt?.toUtc().toIso8601String(),
            'capacity': capacity,
            'vip_quantity': vipQuantity,
          })
          .select('id, name, slug, status, starts_at')
          .single();
      return event;
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  /// Edita um evento draft/published. O slug não é alterado.
  /// [endsAt] nulo limpa a data de término.
  Future<void> updateEvent({
    required String tenantId,
    required String eventId,
    required String name,
    required DateTime startsAt,
    required String venueName,
    required String address,
    required String city,
    required String state,
    required String postalCode,
    String? description,
    DateTime? endsAt,
    int? capacity,
  }) async {
    try {
      final venueId = await _resolveVenueId(
        tenantId: tenantId,
        venueName: venueName,
        address: address,
        city: city,
        state: state,
        postalCode: postalCode,
      );

      final updated = await _client
          .from('events')
          .update({
            'venue_id': venueId,
            'name': name.trim(),
            'description': _nullable(description),
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt?.toUtc().toIso8601String(),
            'capacity': capacity,
          })
          .eq('id', eventId)
          .eq('tenant_id', tenantId)
          .inFilter('status', ['draft', 'published'])
          .select('id');

      if (updated.isEmpty) {
        throw const EventsException(
            'Não foi possível salvar: o evento não pode mais ser editado ou você não tem permissão.');
      }
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  /// draft → published (grava published_at).
  Future<void> publishEvent({
    required String tenantId,
    required String eventId,
  }) =>
      _transition(
        tenantId: tenantId,
        eventId: eventId,
        to: 'published',
        from: const ['draft'],
        extra: {'published_at': DateTime.now().toUtc().toIso8601String()},
      );

  /// draft | published → cancelled.
  Future<void> cancelEvent({
    required String tenantId,
    required String eventId,
  }) =>
      _transition(
        tenantId: tenantId,
        eventId: eventId,
        to: 'cancelled',
        from: const ['draft', 'published'],
      );

  /// published → finished.
  Future<void> finishEvent({
    required String tenantId,
    required String eventId,
  }) =>
      _transition(
        tenantId: tenantId,
        eventId: eventId,
        to: 'finished',
        from: const ['published'],
      );

  /// Faz upload do flyer para o bucket [_coverBucket] em
  /// "{tenantId}/{eventId}.{ext}" e grava o PATH em events.cover_image_path.
  /// Retorna a URL pública para exibição imediata (não é persistida).
  /// [previousPath] (opcional): arquivo antigo, removido se o path mudou.
  Future<String> uploadCoverImage({
    required String tenantId,
    required String eventId,
    required Uint8List bytes,
    required String fileName,
    String? previousPath,
  }) async {
    final rawExtension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final extension =
        _coverExtensions.contains(rawExtension) ? rawExtension : 'jpg';
    final path = '$tenantId/$eventId.$extension';

    try {
      await _client.storage.from(_coverBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeFor(extension),
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      throw EventsException('Não foi possível enviar a imagem: ${e.message}');
    }

    try {
      final updated = await _client
          .from('events')
          .update({'cover_image_path': path})
          .eq('id', eventId)
          .eq('tenant_id', tenantId)
          .select('id');
      if (updated.isEmpty) {
        throw const EventsException(
            'Imagem enviada, mas não foi possível vinculá-la ao evento (evento não encontrado ou sem permissão).');
      }
    } on PostgrestException catch (e) {
      throw _translate(e);
    }

    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath != path) {
      try {
        await _client.storage.from(_coverBucket).remove([previousPath]);
      } catch (_) {
        // Melhor esforço: o arquivo antigo fica órfão, sem afetar o evento.
      }
    }

    return _client.storage.from(_coverBucket).getPublicUrl(path);
  }

  String? getCoverImageUrl(String? coverImagePath) {
    if (coverImagePath == null || coverImagePath.isEmpty) return null;
    return _client.storage.from(_coverBucket).getPublicUrl(coverImagePath);
  }

  Future<void> _transition({
    required String tenantId,
    required String eventId,
    required String to,
    required List<String> from,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      final updated = await _client
          .from('events')
          .update({'status': to, ...extra})
          .eq('id', eventId)
          .eq('tenant_id', tenantId)
          .inFilter('status', from)
          .select('id');
      if (updated.isEmpty) {
        throw const EventsException(
            'Não foi possível alterar o status: o evento não está em um status que permita esta ação, ou você não tem permissão.');
      }
    } on PostgrestException catch (e) {
      throw _translate(e);
    }
  }

  Future<String> _resolveVenueId({
    required String tenantId,
    required String venueName,
    required String address,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    final existingVenue = await _client
        .from('venues')
        .select('id')
        .eq('tenant_id', tenantId)
        .eq('name', venueName.trim())
        .maybeSingle();
    if (existingVenue != null) return existingVenue['id'] as String;

    final created = await _client
        .from('venues')
        .insert({
          'tenant_id': tenantId,
          'name': venueName.trim(),
          'slug': _slug('$venueName-$tenantId'),
          'address_line': address.trim(),
          'address_number': 'S/N',
          'neighborhood': 'Centro',
          'city': city.trim(),
          'state': state.trim().toUpperCase(),
          'postal_code': postalCode.trim(),
          'is_active': true,
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  EventsException _translate(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return const EventsException(
            'Já existe um evento (ou local) com este slug nesta organização.');
      case '23503':
        return const EventsException(
            'Este registro está vinculado a outros dados e não pode ser alterado.');
      case '23514':
        return const EventsException(
            'Valor inválido: confira o status e a capacidade (não pode ser negativa).');
      case '42501':
        return const EventsException(
            'Você não tem permissão para esta ação.');
      default:
        return EventsException(e.message);
    }
  }

  String _contentTypeFor(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return 'local';
    return slug.substring(0, slug.length > 60 ? 60 : slug.length);
  }

  String? _nullable(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}