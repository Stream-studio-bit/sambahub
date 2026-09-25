// CHANGELOG
// 2026-09-18: Provisionamento automático de organização no primeiro login.
// - build() e refresh() agora usam _load(): se o usuário logado não tem nenhuma
//   organização ativa, chama a Edge Function existente provision-workspace
//   (via EventsRepository.ensureWorkspace, sem duplicar a chamada) com
//   profile_type 'venue' (role owner) e recarrega a lista.
// - provision-workspace é idempotente: se já existir membership ativa, devolve a
//   existente, então repetir a chamada não cria outra organização.
// - Se a criação falhar, o erro vai para o estado de erro da tela
//   ("Tentar novamente" refaz o fluxo).
// - updateTenant() sem alteração.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/data/events_repository.dart';
import '../data/tenant_repository.dart';
import '../domain/tenant.dart';

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => TenantRepository(),
);

final tenantControllerProvider =
    AsyncNotifierProvider<TenantController, List<Tenant>>(
  TenantController.new,
);

class TenantController extends AsyncNotifier<List<Tenant>> {
  TenantRepository get _repository => ref.read(tenantRepositoryProvider);

  @override
  Future<List<Tenant>> build() {
    return _load();
  }

  Future<List<Tenant>> _load() async {
    final tenants = await _repository.listForCurrentUser();
    if (tenants.isNotEmpty) return tenants;

    final name = _repository.defaultWorkspaceName();
    if (name == null) return tenants; // sem usuário logado

    await EventsRepository().ensureWorkspace(name: name, profileType: 'venue');
    return _repository.listForCurrentUser();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> updateTenant({
    required String id,
    required String name,
    String? legalName,
    String? email,
    String? phone,
  }) async {
    final previous = state.valueOrNull ?? const <Tenant>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = await _repository.update(
        id: id,
        name: name,
        legalName: legalName,
        email: email,
        phone: phone,
      );
      return [
        for (final tenant in previous)
          if (tenant.id == updated.id) updated else tenant,
      ];
    });
  }
}