// mercadopago-webhook/index.ts
//
// CHANGELOG
// 2.2.0 (2026-09-25): Adicionado disparo de issue-catalog-redemptions junto
//   com triggerIssueTickets, na mesma branch de pagamento aprovado
//   (isApproving). Motivo: issue-tickets (2026-09-25) passou a ignorar
//   order_items do tipo 'catalog' — quem emite o controle de retirada
//   desses itens é a nova function issue-catalog-redemptions. Sem este
//   disparo, pedidos com item de catálogo nunca ganhariam código de
//   resgate.
//   - Nova função triggerIssueCatalogRedemptions(orderId), mesmo padrão de
//     triggerIssueTickets: POST server-to-server com
//     SUPABASE_SERVICE_ROLE_KEY, loga e retorna false em qualquer falha.
//   - As duas chamadas (issue-tickets e issue-catalog-redemptions) rodam
//     sempre juntas na aprovação, e cada uma é independente e idempotente
//     (um pedido só de ingresso não cria nada em catalog_redemptions; um
//     pedido só de catálogo não cria nada em tickets — ambas as functions
//     já tratam isso). Se qualquer uma falhar, a resposta é 502, para o
//     Mercado Pago reenviar a notificação e as duas serem tentadas de novo
//     (idempotentes, então repetir é seguro).
//   - Nenhuma outra lógica alterada: verifyWebhookSignature,
//     findPaymentByProviderTransactionId, fetchPaymentForTenant,
//     mapMercadoPagoStatus, guarda de status terminal, reembolso de
//     tickets, tratamento de data.id ausente/corpo vazio — tudo fora de
//     escopo, intocado.
//
// 2.1.0 (2026-09-22): Duas correções ligadas ao create-payment 2.1.0 (já
//   entregue).
//   - ITEM 1 (guarda contra notificação fora de ordem corrompendo o split):
//     o UPDATE de payment_transactions rodava incondicionalmente sempre
//     que mappedStatus não era 'approved' — só havia guarda
//     (.neq('status','approved')) no sentido aprovar-sobre-aprovado. Uma
//     notificação atrasada/reenviada com status 'pending'/'rejected' podia
//     chegar DEPOIS de uma já processada como 'approved' (ordem de entrega
//     do MP não é garantida) e sobrescrever payment_transactions.status de
//     volta para 'pending', junto com payment_fee (0 nessa fase). Como
//     nenhuma das branches de orderUpdate.status dispara para status
//     'pending', orders.status permanecia 'paid', mas orders.payment_fee
//     incondicional (`orderUpdate.payment_fee = paymentFee`, fora de
//     qualquer branch) era sobrescrito com o valor errado — corrompendo
//     net_amount em settlements silenciosamente, sem erro em log.
//     Corrigido: a UPDATE de payment_transactions agora bloqueia qualquer
//     tentativa de transição vinda de um status já terminal (approved ou
//     refunded) para algo que não seja 'refunded' — via
//     .not('status','in','(approved,refunded)') quando mappedStatus !==
//     'refunded'. Se 0 linhas forem afetadas (bloqueado pela guarda), a
//     função agora IGNORA a notificação por completo — não toca em
//     orders, não recalcula payment_fee, não dispara issue-tickets — e
//     responde 200 (idempotente: nada está errado, só uma notificação
//     obsoleta que corretamente não deve mais alterar nada).
//   - ITEM 2 (decisão de produto 2026-09-22): pagamento 'rejected'/
//     'cancelled' deixa de marcar o PEDIDO como 'cancelled'. Passa a
//     devolver o pedido para 'pending', para alinhar com create-payment
//     2.1.0 (RETRYABLE_MP_STATUSES), que já reverte processing->pending
//     na resposta síncrona — o cliente pode tentar outro cartão no mesmo
//     pedido (fluxo de checkout_controller.submitPayment/_PaymentStep,
//     não alterado). Guarda defensiva adicional (.in('status',
//     ['processing','pending']) no WHERE) para nunca sobrescrever um
//     pedido que já esteja 'paid'/'refunded' por outro caminho — essa
//     branch só deve agir sobre um pedido ainda em tentativa de
//     pagamento. payment_transactions em si continua registrando
//     status='rejected'/'cancelled' normalmente (histórico da tentativa
//     falha preservado; só orders.status muda de comportamento).
//   - Nenhuma outra lógica alterada: verifyWebhookSignature,
//     findPaymentByProviderTransactionId, fetchPaymentForTenant,
//     mapMercadoPagoStatus, triggerIssueTickets, reembolso de tickets,
//     tratamento de data.id ausente/corpo vazio — tudo fora de escopo,
//     intocado.
// 2026-09-21 — Marketplace 1:1 + OAuth (item 9 do prompt de implementação
//   final)
//   - PROBLEMA RESOLVIDO (ovo-e-galinha): com token global, o fluxo era
//     "consulta o pagamento no MP com o token global -> pega
//     external_reference -> acha o pedido local". Com OAuth por tenant, isso
//     não funciona mais: pra consultar o pagamento no MP é preciso o
//     access_token do tenant certo, mas só se sabia qual tenant era depois
//     de consultar o pagamento. Invertida a ordem: agora primeiro localiza a
//     payment_transaction local por (provider, provider_transaction_id) —
//     dataId do webhook é o mesmo id que create-payment já grava em
//     provider_transaction_id no momento da criação (create-payment@2.0.0) —
//     e só então usa o tenant_id desse registro pra resolver o access_token
//     OAuth e confirmar o pagamento de verdade na API do Mercado Pago
//     (fetchPaymentForTenant, _shared/mercadopago.ts@2.0.0). O corpo do
//     webhook em si continua nunca sendo confiado para o estado do
//     pagamento — só para localizar dataId.
//   - findPaymentByProviderTransactionId (_shared/idempotency.ts) estava
//     importada mas nunca chamada no arquivo anterior (import morto) — agora
//     é exatamente essa função que resolve o tenant_id, reaproveitada como
//     estava.
//   - order_id passou a vir do registro local (paymentTransaction.order_id)
//     em vez de mpPayment.external_reference. Mantido um log (não
//     bloqueante) se os dois divergirem — não deveria acontecer, já que
//     create-payment grava external_reference = order_id, mas não impede a
//     resposta 200 caso ocorra, para não travar o reenvio do MP por uma
//     inconsistência que precisa de investigação manual, não de retry.
//   - fetchPayment (token global) removida de _shared/mercadopago.ts —
//     substituída por fetchPaymentForTenant. Erros de resolução de token
//     (MP_NOT_CONNECTED, MP_CONNECTION_EXPIRED etc.) agora são repassados via
//     MercadoPagoError.status/code em vez de sempre 502 genérico.
//   - Resto do fluxo (mapMercadoPagoStatus, reembolso marcando tickets
//     'issued'->'refunded', triggerIssueTickets em toda notificação
//     aprovada, tratamento de data.id ausente) mantido sem alteração de
//     lógica.
// 2026-09-19 — Trilha A, P3b (revisão pós issue-tickets/validate-ticket)
//   - Ponto 1 (corrida): UPDATE de payment_transactions passa a ser
//     condicional (.neq('status','approved')) quando o pagamento está sendo
//     aprovado, evitando que uma notificação duplicada quase simultânea
//     sobrescreva um registro já aprovado. Substituído em 2.1.0 por uma
//     guarda mais ampla (ver acima) que cobre também o sentido inverso.
//   - Ponto 2 (retry sem migration): triggerIssueTickets agora roda em toda
//     notificação aprovada (não só na primeira transição), confere
//     response.ok e, se a chamada falhar, a função devolve 502 em vez de
//     200/201 — isso faz o Mercado Pago reenviar a notificação com backoff.
//     issue-tickets já é idempotente para chamadas sequenciais (P2), então
//     repetir a chamada é seguro.
//   - Ponto 3 (reembolso não invalidava ticket): ao mapear para "refunded"
//     (cobre refunded e charged_back), tickets "issued" do pedido passam a
//     "refunded". Ticket "used" não é alterado. NÃO VALIDADO: se "refunded"
//     é valor aceito no constraint de tickets.status — confirmar antes do
//     deploy com: select conname, pg_get_constraintdef(oid) from
//     pg_constraint where conrelid = 'tickets'::regclass;
//   - Ponto 4 (paid_at zerado no reembolso): NÃO CORRIGIDO — decisão de
//     produto pendente, fora do escopo desta trilha.
//
// Recebe notificações do Mercado Pago, valida assinatura, resolve o tenant
// dono do pagamento a partir do registro local, confirma o pagamento
// consultando a API real com o token OAuth daquele tenant (nunca confia no
// corpo do webhook em si) e atualiza orders/payment_transactions. Ao
// confirmar aprovação, dispara issue-tickets e issue-catalog-redemptions —
// ingressos e resgates de catálogo só existem depois de pagamento
// confirmado no backend (Prompt Mestre, item 4).
//
// Responde rápido: o Mercado Pago reenvia com backoff se não receber
// 200/201 a tempo. Assinatura inválida -> 401 (não reprocessa). Transação
// local ainda não encontrada -> 404 (permite retry, pode ser corrida com
// create-payment). Falha ao resolver/renovar token OAuth do tenant -> status
// do MercadoPagoError (409 se precisa reconectar, 502 se falha de rede/API).
// Falha ao emitir ingressos OU resgates de catálogo -> 502 (força reenvio
// do MP). Notificação obsoleta/fora de ordem (bloqueada pela guarda de
// status terminal) -> 200, ignorada, nada é alterado. Qualquer outro caso
// tratado -> 200/201.

import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient } from "../_shared/supabase.ts";
import { findPaymentByProviderTransactionId } from "../_shared/idempotency.ts";
import {
  extractPaymentFee,
  fetchPaymentForTenant,
  MercadoPagoError,
  verifyWebhookSignature,
} from "../_shared/mercadopago.ts";

interface PaymentTransactionRow {
  id: string;
  tenant_id: string;
  order_id: string;
  status: string;
}

// Status locais que representam um resultado final para o pagamento em si.
// Uma vez nesse estado, nenhuma notificação com status "menos final"
// (pending, rejected, cancelled) pode retroceder o registro — só uma
// transição approved -> refunded é aceita.
const TERMINAL_PAYMENT_STATUSES = "(approved,refunded)";

function mapMercadoPagoStatus(mpStatus: string): string {
  switch (mpStatus) {
    case "approved":
      return "approved";
    case "refunded":
    case "charged_back":
      return "refunded";
    case "cancelled":
      return "cancelled";
    case "rejected":
      return "rejected";
    default:
      return "pending"; // in_process, pending, in_mediation, authorized
  }
}

async function triggerIssueTickets(orderId: string): Promise<boolean> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error(
      `issue-tickets não disparada para order ${orderId}: SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY ausentes.`,
    );
    return false;
  }

  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/issue-tickets`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ order_id: orderId }),
    });

    if (!response.ok) {
      const bodyText = await response.text().catch(() => "");
      console.error(
        `issue-tickets respondeu ${response.status} para order ${orderId}: ${bodyText}`,
      );
      return false;
    }

    return true;
  } catch (err) {
    console.error(`Falha ao chamar issue-tickets para order ${orderId}:`, err);
    return false;
  }
}

// Mesmo padrão de triggerIssueTickets, para os itens de catálogo do pedido
// (order_items.item_type = 'catalog'). Independente e idempotente: um
// pedido sem item de catálogo simplesmente não cria nada.
async function triggerIssueCatalogRedemptions(orderId: string): Promise<boolean> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error(
      `issue-catalog-redemptions não disparada para order ${orderId}: SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY ausentes.`,
    );
    return false;
  }

  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/issue-catalog-redemptions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ order_id: orderId }),
    });

    if (!response.ok) {
      const bodyText = await response.text().catch(() => "");
      console.error(
        `issue-catalog-redemptions respondeu ${response.status} para order ${orderId}: ${bodyText}`,
      );
      return false;
    }

    return true;
  } catch (err) {
    console.error(`Falha ao chamar issue-catalog-redemptions para order ${orderId}:`, err);
    return false;
  }
}

Deno.serve(async (req: Request) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  if (req.method !== "POST") {
    return jsonError("METHOD_NOT_ALLOWED", "Use POST.", { status: 405, requestId });
  }

  const url = new URL(req.url);
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    // Mercado Pago às vezes envia corpo vazio em notificações de teste.
  }

  const dataFromBody = (body?.data as { id?: string } | undefined)?.id ?? null;
  const dataId = url.searchParams.get("data.id") ?? dataFromBody;
  const xSignature = req.headers.get("x-signature");
  const xRequestId = req.headers.get("x-request-id");

  const signatureValid = await verifyWebhookSignature({
    xSignature,
    xRequestId,
    dataId,
  });

  if (!signatureValid) {
    return jsonError("INVALID_SIGNATURE", "Assinatura do webhook inválida.", {
      status: 401,
      requestId,
    });
  }

  if (!dataId) {
    // Notificação sem data.id (ex.: teste de configuração) — confirma
    // recebimento sem processar nada.
    return jsonSuccess({ ignored: true }, { requestId });
  }

  const client = getServiceRoleClient();

  // Resolve o registro local ANTES de chamar o Mercado Pago: é dele que sai
  // o tenant_id necessário para obter o access_token OAuth correto. dataId é
  // o mesmo id que create-payment grava em provider_transaction_id.
  let paymentTransaction: PaymentTransactionRow | null;
  try {
    paymentTransaction = await findPaymentByProviderTransactionId<PaymentTransactionRow>(
      client,
      "mercadopago",
      dataId,
    );
  } catch (err) {
    return jsonError("INTERNAL_ERROR", "Falha ao consultar transação de pagamento local.", {
      status: 500,
      details: (err as Error).message,
      requestId,
    });
  }

  if (!paymentTransaction) {
    // Pode ser corrida com create-payment ainda não commitado. Permite retry.
    return jsonError("ORDER_NOT_FOUND", "Nenhuma transação local para este pagamento ainda.", {
      status: 404,
      requestId,
    });
  }

  const orderId = paymentTransaction.order_id;

  let mpPayment;
  try {
    mpPayment = await fetchPaymentForTenant(paymentTransaction.tenant_id, dataId);
  } catch (err) {
    if (err instanceof MercadoPagoError) {
      return jsonError(err.code, err.message, { status: err.status, requestId });
    }
    return jsonError("MERCADOPAGO_ERROR", "Falha ao consultar pagamento no Mercado Pago.", {
      status: 502,
      details: (err as Error).message,
      requestId,
    });
  }

  if (mpPayment.external_reference && mpPayment.external_reference !== orderId) {
    // Não deveria acontecer (create-payment grava external_reference =
    // order_id), mas não trava a resposta por isso — é caso de investigação
    // manual, não de retry pelo Mercado Pago.
    console.error(
      `Divergência: payment_transaction ${paymentTransaction.id} aponta para order ${orderId}, mas o pagamento ${dataId} no Mercado Pago tem external_reference ${mpPayment.external_reference}.`,
    );
  }

  const mappedStatus = mapMercadoPagoStatus(mpPayment.status);
  const paymentFee = extractPaymentFee(mpPayment);
  const isApproving = mappedStatus === "approved";

  const paymentTransactionUpdate: Record<string, unknown> = {
    provider_transaction_id: String(mpPayment.id),
    status: mappedStatus,
    payment_fee: paymentFee,
    provider_status: mpPayment.status_detail,
    provider_payload: mpPayment,
    paid_at: isApproving ? mpPayment.date_approved ?? new Date().toISOString() : null,
    refunded_at: mappedStatus === "refunded" ? new Date().toISOString() : null,
    last_webhook_at: new Date().toISOString(),
  };

  let updatePaymentQuery = client
    .from("payment_transactions")
    .update(paymentTransactionUpdate)
    .eq("id", paymentTransaction.id);

  // Guarda única contra notificação fora de ordem: qualquer status que não
  // seja 'refunded' é bloqueado se o registro já estiver num status
  // terminal (approved ou refunded). Cobre tanto "aprovado duplicado" (já
  // era o comportamento anterior) quanto "notificação antiga/atrasada
  // retrocedendo um pagamento já aprovado/reembolsado" (o bug corrigido
  // nesta versão). 'refunded' nunca é bloqueado: é sempre a transição mais
  // final possível.
  if (mappedStatus !== "refunded") {
    updatePaymentQuery = updatePaymentQuery.not("status", "in", TERMINAL_PAYMENT_STATUSES);
  }

  const { data: updatedPaymentRows, error: updatePaymentError } = await updatePaymentQuery.select(
    "id",
  );

  if (updatePaymentError) {
    return jsonError("INTERNAL_ERROR", "Falha ao atualizar transação de pagamento.", {
      status: 500,
      details: updatePaymentError.message,
      requestId,
    });
  }

  const paymentUpdateApplied = (updatedPaymentRows?.length ?? 0) > 0;

  if (!paymentUpdateApplied) {
    // Bloqueado pela guarda acima: payment_transactions já está num status
    // terminal e esta notificação é mais antiga/menos final que o estado
    // atual. Não toca em orders (é aqui que o bug de payment_fee corrompido
    // era introduzido antes desta versão) nem dispara issue-tickets.
    // Idempotente do ponto de vista do MP — não é erro, não precisa retry.
    console.log(
      `Notificação ${dataId} (status MP '${mpPayment.status}' -> '${mappedStatus}') ignorada para order ${orderId}: payment_transactions já está em status terminal.`,
    );
    return jsonSuccess({ order_id: orderId, status: mappedStatus, ignored: true }, { requestId });
  }

  const orderUpdate: Record<string, unknown> = { payment_fee: paymentFee };
  let orderUpdateQuery = client.from("orders").update(orderUpdate).eq("id", orderId);

  if (mappedStatus === "approved") {
    orderUpdate.status = "paid";
    orderUpdate.paid_at = mpPayment.date_approved ?? new Date().toISOString();
  } else if (mappedStatus === "rejected" || mappedStatus === "cancelled") {
    // Decisão de produto (2026-09-22): devolve o pedido para 'pending' em
    // vez de 'cancelled', para permitir nova tentativa de pagamento com
    // outro cartão — alinhado com create-payment 2.1.0
    // (RETRYABLE_MP_STATUSES), que já faz essa mesma reversão na resposta
    // síncrona. Guarda defensiva: só aplica se o pedido ainda estiver em
    // tentativa de pagamento ('processing' ou já revertido para
    // 'pending' pelo create-payment antes deste webhook chegar) — nunca
    // sobrescreve um pedido que por qualquer outro caminho já tenha
    // chegado a 'paid'/'refunded'.
    orderUpdate.status = "pending";
    orderUpdateQuery = orderUpdateQuery.in("status", ["processing", "pending"]);
  } else if (mappedStatus === "refunded") {
    orderUpdate.status = "refunded";
    orderUpdate.refunded_at = new Date().toISOString();
  }

  const { error: updateOrderError } = await orderUpdateQuery;

  if (updateOrderError) {
    return jsonError("INTERNAL_ERROR", "Falha ao atualizar o pedido.", {
      status: 500,
      details: updateOrderError.message,
      requestId,
    });
  }

  if (mappedStatus === "refunded") {
    const { error: refundTicketsError } = await client
      .from("tickets")
      .update({ status: "refunded" })
      .eq("order_id", orderId)
      .eq("status", "issued");

    if (refundTicketsError) {
      // Não bloqueia a resposta: transação e pedido já foram atualizados.
      // Fica registrado para investigação manual (um ticket "issued" ainda
      // passaria no validate-ticket até isso ser corrigido).
      console.error(
        `Falha ao marcar tickets como refunded para order ${orderId}:`,
        refundTicketsError.message,
      );
    }
  }

  if (isApproving) {
    // Disparadas em toda notificação aprovada (não só na primeira
    // transição): as duas functions são idempotentes para chamadas
    // sequenciais, então isso cobre o caso de uma tentativa anterior ter
    // falhado. As duas rodam sempre juntas — cada uma trata os itens do
    // tipo que lhe cabe e não faz nada se o pedido não tiver desse tipo.
    const [ticketsIssued, catalogRedemptionsIssued] = await Promise.all([
      triggerIssueTickets(orderId),
      triggerIssueCatalogRedemptions(orderId),
    ]);
    if (!ticketsIssued || !catalogRedemptionsIssued) {
      return jsonError(
        "ISSUE_FULFILLMENT_FAILED",
        "Falha ao emitir ingressos ou resgates de catálogo para o pedido.",
        { status: 502, requestId },
      );
    }
  }

  return jsonSuccess({ order_id: orderId, status: mappedStatus }, { requestId });
});