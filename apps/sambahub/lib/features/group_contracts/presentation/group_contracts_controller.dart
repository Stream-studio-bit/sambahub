// CHANGELOG
// 2026-09-19 — P6 / Trilha D (Contratos de grupo)
// - refresh() não troca mais o state por AsyncLoading antes de recarregar:
//   isso apagava a lista inteira a cada RefreshIndicator ou após uma
//   mutação, voltando para o spinner mesmo com dados já carregados.
// - Adicionadas as mutações createContract/editContract/signContract/
//   payContract/cancelContract. Seguem o padrão do prompt mestre: a mutação
//   não mexe no AsyncValue de loading, deixa a exceção subir para a página
//   (que trata o "ocupado" localmente) e, no sucesso, recarrega a lista
//   chamando refresh().
// - Adicionados dois FutureProviderFamily (groupContractGroupOptionsProvider
//   e groupContractEventOptionsProvider) para alimentar os seletores de
//   grupo/evento do formulário de criação, sem criar repository novo.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_contracts_repository.dart';
import '../domain/group_contract.dart';

final groupContractsRepositoryProvider = Provider<GroupContractsRepository>(
  (ref) => GroupContractsRepository(),
);

final groupContractsControllerProvider = AsyncNotifierProviderFamily<
    GroupContractsController, List<GroupContract>, String>(
  GroupContractsController.new,
);

final groupContractGroupOptionsProvider =
    FutureProvider.family<List<ContractOption>, String>((ref, tenantId) {
  return ref
      .read(groupContractsRepositoryProvider)
      .listGroupOptions(tenantId: tenantId);
});

final groupContractEventOptionsProvider =
    FutureProvider.family<List<ContractOption>, String>((ref, tenantId) {
  return ref
      .read(groupContractsRepositoryProvider)
      .listEventOptions(tenantId: tenantId);
});

class GroupContractsController
    extends FamilyAsyncNotifier<List<GroupContract>, String> {
  GroupContractsRepository get _repository =>
      ref.read(groupContractsRepositoryProvider);

  @override
  Future<List<GroupContract>> build(String tenantId) {
    return _repository.list(tenantId: tenantId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.list(tenantId: arg));
  }

  Future<void> createContract({
    required String groupId,
    required String eventId,
    required String feeAmount,
    required DateTime startsAt,
    DateTime? endsAt,
    String? terms,
  }) async {
    await _repository.create(
      tenantId: arg,
      groupId: groupId,
      eventId: eventId,
      feeAmount: feeAmount,
      startsAt: startsAt,
      endsAt: endsAt,
      terms: terms,
    );
    await refresh();
  }

  Future<void> editContract({
    required String id,
    required String feeAmount,
    required DateTime startsAt,
    DateTime? endsAt,
    String? terms,
  }) async {
    await _repository.edit(
      tenantId: arg,
      id: id,
      feeAmount: feeAmount,
      startsAt: startsAt,
      endsAt: endsAt,
      terms: terms,
    );
    await refresh();
  }

  Future<void> signContract(String id) async {
    await _repository.sign(tenantId: arg, id: id);
    await refresh();
  }

  Future<void> payContract(String id) async {
    await _repository.pay(tenantId: arg, id: id);
    await refresh();
  }

  Future<void> cancelContract(String id) async {
    await _repository.cancel(tenantId: arg, id: id);
    await refresh();
  }
}