// CHANGELOG
// 2026-09-19 — P7 / Trilha E (Membros)
// - refresh() não troca mais o state por AsyncLoading antes de recarregar
//   (apagava a lista a cada pull-to-refresh ou após uma mutação).
// - updateRole/updateStatus ganharam a proteção do owner exigida pelo prompt
//   mestre ("na UI e no controller"): a RLS (memberships_manage) não
//   distingue a linha do owner de nenhuma outra, então nada impede uma
//   chamada direta de trocar o role ou suspender o próprio owner. A checagem
//   aqui barra isso antes de qualquer chamada de rede, mesmo que a proteção
//   da UI seja contornada.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/members_repository.dart';
import '../domain/tenant_member.dart';

final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) => MembersRepository(),
);

final membersControllerProvider =
    AsyncNotifierProviderFamily<MembersController, List<TenantMember>, String>(
  MembersController.new,
);

class MembersController
    extends FamilyAsyncNotifier<List<TenantMember>, String> {
  MembersRepository get _repository => ref.read(membersRepositoryProvider);

  @override
  Future<List<TenantMember>> build(String tenantId) {
    return _repository.list(tenantId: tenantId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.list(tenantId: arg));
  }

  Future<void> updateRole(TenantMember member, String role) async {
    if (member.isOwner) {
      throw const MembersException(
        'Não é possível alterar a função do proprietário da organização.',
      );
    }
    await _repository.updateRole(
      tenantId: arg,
      membershipId: member.id,
      role: role,
    );
    await refresh();
  }

  Future<void> updateStatus(TenantMember member, String status) async {
    if (member.isOwner) {
      throw const MembersException(
        'Não é possível suspender o proprietário da organização.',
      );
    }
    await _repository.updateStatus(
      tenantId: arg,
      membershipId: member.id,
      status: status,
    );
    await refresh();
  }
}