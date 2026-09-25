// CHANGELOG
// 2026-09-19: P10 (Trilha G) — criado o controller de eventos
// (lib/features/events/presentation/events_controller.dart). AsyncNotifier
// family por tenantId, no mesmo padrão dos controllers de pedidos/pagamentos.
// - Lista via EventsRepository.listEvents; refresh() recarrega.
// - Mutações (updateEvent, publish, cancel, finish, uploadCover) NÃO trocam o
//   state por AsyncLoading: propagam a EventsException para a página e
//   recarregam a lista no sucesso.
// - Bloqueia ação incompatível antes de chamar o repository:
//   editar/cancelar só draft|published; publicar só draft; finalizar só
//   published. Valida nome, término após início e capacidade >= 0.
//   (Regra financeira/ingressos de cancelamento não é tratada aqui.)

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/events_repository.dart';
import '../domain/event.dart';

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(),
);

final eventsControllerProvider = AsyncNotifierProvider.family<
    EventsController, List<SambaEvent>, String>(EventsController.new);

class EventsController extends FamilyAsyncNotifier<List<SambaEvent>, String> {
  EventsRepository get _repository => ref.read(eventsRepositoryProvider);

  String get _tenantId => arg;

  @override
  Future<List<SambaEvent>> build(String arg) => _repository.listEvents(arg);

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.listEvents(_tenantId));
  }

  Future<void> updateEvent({
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
    final event = _find(eventId);
    if (!(event.isDraft || event.isPublished)) {
      throw const EventsException(
          'Só é possível editar eventos em rascunho ou publicados.');
    }
    if (name.trim().isEmpty) {
      throw const EventsException('Informe o nome do evento.');
    }
    if (endsAt != null && !endsAt.isAfter(startsAt)) {
      throw const EventsException(
          'O término deve ser depois do início do evento.');
    }
    if (capacity != null && capacity < 0) {
      throw const EventsException('A capacidade não pode ser negativa.');
    }

    await _repository.updateEvent(
      tenantId: _tenantId,
      eventId: eventId,
      name: name,
      startsAt: startsAt,
      venueName: venueName,
      address: address,
      city: city,
      state: state,
      postalCode: postalCode,
      description: description,
      endsAt: endsAt,
      capacity: capacity,
    );
    await refresh();
  }

  Future<void> publish(String eventId) async {
    if (!_find(eventId).isDraft) {
      throw const EventsException(
          'Só é possível publicar eventos em rascunho.');
    }
    await _repository.publishEvent(tenantId: _tenantId, eventId: eventId);
    await refresh();
  }

  Future<void> cancel(String eventId) async {
    final event = _find(eventId);
    if (!(event.isDraft || event.isPublished)) {
      throw const EventsException(
          'Só é possível cancelar eventos em rascunho ou publicados.');
    }
    await _repository.cancelEvent(tenantId: _tenantId, eventId: eventId);
    await refresh();
  }

  Future<void> finish(String eventId) async {
    if (!_find(eventId).isPublished) {
      throw const EventsException(
          'Só é possível finalizar eventos publicados.');
    }
    await _repository.finishEvent(tenantId: _tenantId, eventId: eventId);
    await refresh();
  }

  Future<void> uploadCover({
    required String eventId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final event = _find(eventId);
    if (!(event.isDraft || event.isPublished)) {
      throw const EventsException(
          'Só é possível trocar o flyer de eventos em rascunho ou publicados.');
    }
    await _repository.uploadCoverImage(
      tenantId: _tenantId,
      eventId: eventId,
      bytes: bytes,
      fileName: fileName,
      previousPath: event.coverImagePath,
    );
    await refresh();
  }

  SambaEvent _find(String eventId) {
    final events = state.valueOrNull ?? const <SambaEvent>[];
    for (final event in events) {
      if (event.id == eventId) return event;
    }
    throw const EventsException(
        'Evento não encontrado. Atualize a lista e tente de novo.');
  }
}