// CHANGELOG
// 2026-09-19 — P5 / Trilha C (Relatórios)
// - ReportQuery agora normaliza o período no construtor (fábrica `period`):
//   início no primeiro instante do dia e fim no último. Isso torna a chave da
//   família estável: antes a página montava a query com DateTime.now() dentro
//   do build, e como periodEnd mudava a cada milissegundo o Riverpod criava um
//   provider novo e refazia o RPC a cada rebuild.
// - refresh() não troca mais o state por AsyncLoading. Com o RefreshIndicator
//   isso apagava a tela inteira e voltava ao spinner a cada recarga; agora os
//   dados anteriores continuam visíveis até chegar o resultado novo.
// - Mantidos os nomes reportsRepositoryProvider, reportsControllerProvider,
//   ReportQuery, ReportsController e refresh(). Sem troca de base class.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reports_repository.dart';
import '../domain/report_summary.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(),
);

final reportsControllerProvider =
    AsyncNotifierProviderFamily<ReportsController, ReportSummary, ReportQuery>(
  ReportsController.new,
);

class ReportQuery {
  const ReportQuery({
    required this.tenantId,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Constrói a consulta com o período normalizado por dia, garantindo que a
  /// chave da família não mude a cada rebuild da página.
  factory ReportQuery.period({
    required String tenantId,
    required DateTime start,
    required DateTime end,
  }) {
    return ReportQuery(
      tenantId: tenantId,
      periodStart: DateTime(start.year, start.month, start.day),
      periodEnd:
          DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
    );
  }

  final String tenantId;
  final DateTime periodStart;
  final DateTime periodEnd;

  @override
  bool operator ==(Object other) =>
      other is ReportQuery &&
      other.tenantId == tenantId &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd;

  @override
  int get hashCode => Object.hash(tenantId, periodStart, periodEnd);

  @override
  String toString() =>
      'ReportQuery($tenantId, $periodStart, $periodEnd)';
}

class ReportsController
    extends FamilyAsyncNotifier<ReportSummary, ReportQuery> {
  ReportsRepository get _repository => ref.read(reportsRepositoryProvider);

  @override
  Future<ReportSummary> build(ReportQuery query) {
    return _repository.summary(
      tenantId: query.tenantId,
      periodStart: query.periodStart,
      periodEnd: query.periodEnd,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => _repository.summary(
        tenantId: arg.tenantId,
        periodStart: arg.periodStart,
        periodEnd: arg.periodEnd,
      ),
    );
  }
}