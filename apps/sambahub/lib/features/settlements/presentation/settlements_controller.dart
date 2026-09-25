// CHANGELOG
// 2026-09-19 — P8 / Trilha C (Repasses)
// - refresh() não troca mais o state por AsyncLoading antes de recarregar:
//   apagava a lista inteira a cada RefreshIndicator, voltando ao spinner
//   mesmo com dados já carregados (mesma correção aplicada nas trilhas
//   anteriores).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settlements_repository.dart';
import '../domain/settlement.dart';

final settlementsRepositoryProvider = Provider<SettlementsRepository>(
  (ref) => SettlementsRepository(),
);

final settlementsControllerProvider = AsyncNotifierProviderFamily<
    SettlementsController, List<Settlement>, String>(
  SettlementsController.new,
);

class SettlementsController
    extends FamilyAsyncNotifier<List<Settlement>, String> {
  SettlementsRepository get _repository =>
      ref.read(settlementsRepositoryProvider);

  @override
  Future<List<Settlement>> build(String tenantId) {
    return _repository.list(tenantId: tenantId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repository.list(tenantId: arg));
  }
}