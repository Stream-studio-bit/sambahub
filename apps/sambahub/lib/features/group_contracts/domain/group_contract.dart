// CHANGELOG
// 2026-09-19 — P6 / Trilha D (Contratos de grupo)
// - Removido o campo `title`: a coluna nunca existiu em group_contracts (só
//   existem draft/signed/paid/cancelled em `status`, conferido em
//   20260915000015_create_group_contracts.sql e em toda a migration
//   subsequente que toca a tabela). Em vez de inventar uma coluna, o título
//   exibido passa a ser `eventName`, vindo do join com `events(name)` — dado
//   real que já existe, e o contrato exige event_id not null de qualquer
//   forma.
// - `endsAt` passou a ser `DateTime?`. A coluna é nullable no banco; o código
//   anterior fazia `DateTime.parse(map['ends_at'].toString())`, que lança
//   FormatException quando o valor é null (vira a string "null").
// - `eventId` passou a ser obrigatório (String, não String?), refletindo o
//   `not null` da coluna.
// - `feeAmount` agora lê `cache_amount` (nome real da coluna). O código
//   anterior lia `fee_amount`, que não existe — isso sempre resultava em
//   FormatException/cast nulo ao montar o objeto.
// - Removido `isActive`/status 'active': esse valor não está no CHECK da
//   coluna (`draft, signed, paid, cancelled`) e nunca vai aparecer no banco.
// - Adicionados getters de transição (canEdit/canSign/canPay/canCancel) para
//   o controller e a página não duplicarem a mesma regra em dois lugares.
//   Não há trigger nem constraint de transição no banco (confirmado via
//   pg_constraint / grep nas migrations); a regra abaixo é só de aplicação,
//   igual à "proposta padrão" do prompt mestre.

class GroupContract {
  const GroupContract({
    required this.id,
    required this.tenantId,
    required this.groupId,
    required this.eventId,
    required this.status,
    required this.feeAmount,
    required this.currency,
    required this.startsAt,
    required this.createdAt,
    this.endsAt,
    this.terms,
    this.signedAt,
    this.paidAt,
    this.groupName,
    this.eventName,
  });

  final String id;
  final String tenantId;
  final String groupId;
  final String eventId;
  final String status;
  final String feeAmount;
  final String currency;
  final DateTime startsAt;
  final DateTime createdAt;
  final DateTime? endsAt;
  final String? terms;
  final DateTime? signedAt;
  final DateTime? paidAt;
  final String? groupName;
  final String? eventName;

  bool get canEdit => status == 'draft';
  bool get canSign => status == 'draft';
  bool get canPay => status == 'signed';
  bool get canCancel => status == 'draft' || status == 'signed';
  bool get isFinal => status == 'paid' || status == 'cancelled';

  factory GroupContract.fromMap(Map<String, dynamic> map) {
    final group = map['groups'] as Map<String, dynamic>?;
    final event = map['events'] as Map<String, dynamic>?;
    return GroupContract(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      groupId: map['group_id'] as String,
      eventId: map['event_id'] as String,
      status: map['status'] as String,
      feeAmount: map['cache_amount'].toString(),
      currency: map['currency'] as String? ?? 'BRL',
      startsAt: DateTime.parse(map['starts_at'].toString()),
      endsAt: map['ends_at'] == null
          ? null
          : DateTime.tryParse(map['ends_at'].toString()),
      createdAt: DateTime.parse(map['created_at'].toString()),
      terms: map['terms'] as String?,
      signedAt: map['signed_at'] == null
          ? null
          : DateTime.tryParse(map['signed_at'].toString()),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.tryParse(map['paid_at'].toString()),
      groupName: group?['name'] as String?,
      eventName: event?['name'] as String?,
    );
  }
}