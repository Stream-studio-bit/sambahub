// create-payment/index.ts
// Cria o pagamento no Mercado Pago via Checkout Transparente/Payment Brick
// (Marketplace 1:1) para um pedido já existente, usando o OAuth Access
// Token do vendedor do tenant e aplicando a comissão de 1% do SambaHub via
// application_fee. Function distinta de create-public-order (Prompt Mestre,
// item 10).
//
// CHANGELOG
// 2.1.0 (2026-09-22): Correção de condição de corrida no split de 1% —
//   duas chamadas concorrentes a este endpoint (duplo clique, retry de
//   rede, reenvio do Brick) passavam ambas pela checagem de
//   order.status/existingPayment ANTES de qualquer uma persistir algo,
//   chegando as duas a createTenantPayment: cobrança duplicada no MP, cada
//   uma com application_fee própria, e só a segunda gravação local falhava
//   (unique constraint) — a segunda transação no MP ficava sem
//   payment_transactions correspondente, invisível em conciliação.
//   Corrigido com claim atômico: UPDATE orders SET status='processing'
//   WHERE id=:id AND status='pending' (condicional no próprio WHERE, não
//   um SELECT-then-UPDATE). Se 0 linhas afetadas, outra requisição já
//   reivindicou o pedido — retorna 409 ORDER_NOT_PAYABLE sem nunca chamar
//   o Mercado Pago. Requer que a migration de orders passe a aceitar
//   status='processing' no check constraint (a ser entregue à parte).
//   revertOrderToPending() devolve o pedido a 'pending' (só de
//   'processing', nunca de 'paid'/outro) em dois casos: (1) qualquer falha
//   ao chamar createTenantPayment ou ao persistir payment_transactions —
//   senão o pedido ficava travado em 'processing' para sempre, sem
//   possibilidade de nova tentativa; (2) pagamento respondido como
//   'rejected'/'cancelled' pelo MP — preserva o fluxo existente de
//   checkout_controller.submitPayment, que permite ao cliente tentar outro
//   cartão no mesmo pedido. Pagamento 'approved'/'pending'/'in_process'/
//   'authorized' mantém o pedido em 'processing' (mercadopago-webhook
//   assume dali para 'paid'; não impede reconciliação manual se o webhook
//   nunca chegar — risco preexistente, não introduzido por esta mudança).
//   Também adicionada validação de gross_amount: Number(order.gross_amount)
//   podia virar NaN (dado corrompido) e JSON.stringify(NaN) vira null —
//   o MP aceitava o pagamento com application_fee: null, retendo 0% de
//   comissão silenciosamente, sem erro em lugar nenhum. Agora rejeitado
//   antes de chamar o MP.
//   Nenhuma outra lógica alterada: createTenantPayment, extractPaymentFee,
//   formato do envelope de resposta, payment_transactions fields — tudo
//   fora de escopo, intocado.
// 2.0.0 (2026-09-21): Substituído o fluxo Checkout Pro (createPreference /
//   payment_url / init_point) pelo Checkout Transparente com Payment Brick
//   (Prompt Mestre, item 6). Removida a dependência de PUBLIC_WEB_URL e
//   back_urls — Payment Brick não redireciona, não há mais tela de retorno.
//   O pagamento agora é criado com o access_token OAuth do tenant (via
//   getValidAccessToken/createTenantPayment em _shared/mercadopago.ts@2.0.0),
//   nunca mais com MERCADOPAGO_ACCESS_TOKEN global. platform_fee (1% do
//   gross_amount) é calculado aqui e enviado como application_fee — nunca
//   persistido em orders por esta function: orders.platform_fee/payment_fee/
//   net_amount/paid_at continuam sendo escritos exclusivamente pelo
//   mercadopago-webhook (item 9), que recalcula o mesmo 1% de forma
//   determinística a partir de gross_amount (orders.status agora também
//   pode ser escrito por este arquivo, mas só para 'processing'/'pending'
//   — 'paid' continua exclusivo do webhook). payment_transactions passou a
//   guardar provider_transaction_id, status, payment_fee e provider_status
//   já na criação (antes só guardava init_point/id do Checkout Pro).
//   Endpoint deixou de ser 100% "sem dado sensível de pagamento": agora
//   recebe token/payment_method_id do Brick — nunca logar esses campos nem
//   o corpo bruto do payload.
// 1.0.0: versão original (Checkout Pro / createPreference).

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient } from "../_shared/supabase.ts";
import {
  createTenantPayment,
  extractPaymentFee,
  MercadoPagoError,
  MercadoPagoPayment,
} from "../_shared/mercadopago.ts";

interface CreatePaymentPayload {
  order_id?: string;
  payment_method_id?: string;
  token?: string;
  installments?: number | string;
  issuer_id?: string | number;
  payer?: {
    email?: string;
    identification?: { type?: string; number?: string };
  };
}

interface OrderRow {
  id: string;
  tenant_id: string;
  status: string;
  customer_email: string;
  idempotency_key: string;
  gross_amount: number | string;
  order_items: {
    product_name: string;
    quantity: number;
  }[];
}

interface PaymentTransactionRow {
  id: string;
  status: string;
}

// Status finais em que o Mercado Pago não deve mais permitir nova
// tentativa de pagamento no mesmo pedido — o pedido volta a 'pending'
// para o cliente poder tentar outro método/cartão (mantém o fluxo já
// existente em checkout_controller.submitPayment).
const RETRYABLE_MP_STATUSES = new Set(["rejected", "cancelled"]);

function roundCurrency(value: number): number {
  return Math.round(value * 100) / 100;
}

Deno.serve(async (req: Request) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") return handleCorsPreflight();

  if (req.method !== "POST") {
    return jsonError("METHOD_NOT_ALLOWED", "Use POST.", { status: 405, requestId });
  }

  let payload: CreatePaymentPayload;
  try {
    payload = await req.json();
  } catch {
    return jsonError("INVALID_JSON", "Corpo da requisição inválido.", { status: 400, requestId });
  }

  const orderId = payload.order_id?.trim();
  const paymentMethodId = payload.payment_method_id?.trim();
  const payerEmail = payload.payer?.email?.trim();

  if (!orderId) {
    return jsonError("VALIDATION_ERROR", "order_id é obrigatório.", { status: 400, requestId });
  }
  if (!paymentMethodId) {
    return jsonError("VALIDATION_ERROR", "payment_method_id é obrigatório.", {
      status: 400,
      requestId,
    });
  }
  if (!payerEmail) {
    return jsonError("VALIDATION_ERROR", "payer.email é obrigatório.", {
      status: 400,
      requestId,
    });
  }

  const client = getServiceRoleClient();

  const { data: order, error: orderError } = await client
    .from("orders")
    .select(
      "id, tenant_id, status, customer_email, idempotency_key, gross_amount, order_items(product_name, quantity)",
    )
    .eq("id", orderId)
    .maybeSingle<OrderRow>();

  if (orderError) {
    return jsonError("INTERNAL_ERROR", "Falha ao consultar o pedido.", {
      status: 500,
      details: orderError.message,
      requestId,
    });
  }

  if (!order) {
    return jsonError("ORDER_NOT_FOUND", "Pedido não encontrado.", { status: 404, requestId });
  }

  if (!order.tenant_id) {
    return jsonError("INTERNAL_ERROR", "Pedido sem tenant_id associado.", {
      status: 500,
      requestId,
    });
  }

  // Checagem rápida (mensagem amigável) antes do claim atômico abaixo. Não
  // substitui o claim — dois requests concorrentes podem passar por aqui
  // ambos vendo status 'pending'; quem garante exclusividade de fato é o
  // UPDATE condicional a seguir.
  if (order.status !== "pending") {
    return jsonError(
      "ORDER_NOT_PAYABLE",
      `Pedido está com status '${order.status}' e não pode gerar novo pagamento.`,
      { status: 409, requestId },
    );
  }

  const grossAmount = Number(order.gross_amount);
  if (!Number.isFinite(grossAmount) || grossAmount <= 0) {
    return jsonError(
      "INVALID_GROSS_AMOUNT",
      "gross_amount do pedido é inválido — não é possível calcular a comissão.",
      { status: 500, requestId },
    );
  }

  const { data: existingPayment, error: existingPaymentError } = await client
    .from("payment_transactions")
    .select("id, status")
    .eq("order_id", orderId)
    .maybeSingle<PaymentTransactionRow>();

  if (existingPaymentError) {
    return jsonError("INTERNAL_ERROR", "Falha ao consultar pagamento existente.", {
      status: 500,
      details: existingPaymentError.message,
      requestId,
    });
  }

  if (existingPayment && existingPayment.status === "approved") {
    return jsonError("ORDER_ALREADY_PAID", "Este pedido já foi pago.", {
      status: 409,
      requestId,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) {
    return jsonError(
      "INTERNAL_ERROR",
      "SUPABASE_URL não configurada no ambiente da Edge Function.",
      { status: 500, requestId },
    );
  }

  // Claim atômico do pedido: só quem conseguir transicionar
  // pending -> processing pode prosseguir para o Mercado Pago. Se 0 linhas
  // afetadas, outra requisição concorrente já reivindicou este pedido —
  // barra aqui, antes de qualquer chamada externa que geraria cobrança
  // real e application_fee duplicada.
  const { data: claimedRows, error: claimError } = await client
    .from("orders")
    .update({ status: "processing" })
    .eq("id", orderId)
    .eq("status", "pending")
    .select("id");

  if (claimError) {
    return jsonError("INTERNAL_ERROR", "Falha ao reivindicar o pedido para pagamento.", {
      status: 500,
      details: claimError.message,
      requestId,
    });
  }

  if (!claimedRows || claimedRows.length === 0) {
    return jsonError(
      "ORDER_NOT_PAYABLE",
      "Este pedido já está sendo processado em outra requisição.",
      { status: 409, requestId },
    );
  }

  const revertOrderToPending = async () => {
    // Só reverte de 'processing' — nunca sobrescreve um status que o
    // webhook (ou outra concorrente legítima) já tenha avançado para
    // 'paid' entre o claim e este ponto.
    await client
      .from("orders")
      .update({ status: "pending" })
      .eq("id", orderId)
      .eq("status", "processing");
  };

  const applicationFee = roundCurrency(grossAmount * 0.01);

  const description = order.order_items.length
    ? order.order_items.map((item) => `${item.quantity}x ${item.product_name}`).join(", ")
    : `Pedido ${order.id}`;

  let payment: MercadoPagoPayment;
  try {
    payment = await createTenantPayment({
      tenantId: order.tenant_id,
      orderId: order.id,
      transactionAmount: grossAmount,
      applicationFee,
      description,
      notificationUrl: `${supabaseUrl}/functions/v1/mercadopago-webhook`,
      idempotencyKey: order.idempotency_key,
      paymentMethodId,
      token: payload.token,
      installments: payload.installments !== undefined ? Number(payload.installments) : undefined,
      issuerId: payload.issuer_id !== undefined ? String(payload.issuer_id) : undefined,
      payer: {
        email: payerEmail || order.customer_email,
        identification: payload.payer?.identification?.type && payload.payer?.identification?.number
          ? {
              type: payload.payer.identification.type,
              number: payload.payer.identification.number,
            }
          : undefined,
      },
    });
  } catch (err) {
    await revertOrderToPending();
    if (err instanceof MercadoPagoError) {
      return jsonError(err.code, err.message, { status: err.status, requestId });
    }
    return jsonError("INTERNAL_ERROR", "Falha inesperada ao criar pagamento.", {
      status: 500,
      details: (err as Error).message,
      requestId,
    });
  }

  const paymentFee = extractPaymentFee(payment);
  const paidAt = payment.status === "approved" ? payment.date_approved ?? new Date().toISOString() : null;

  const transactionFields = {
    tenant_id: order.tenant_id,
    order_id: order.id,
    provider: "mercadopago",
    idempotency_key: order.idempotency_key,
    status: payment.status,
    amount: order.gross_amount,
    payment_fee: paymentFee,
    provider_transaction_id: String(payment.id),
    provider_status: payment.status_detail,
    provider_payload: payment,
    paid_at: paidAt,
  };

  if (existingPayment) {
    const { error: updateError } = await client
      .from("payment_transactions")
      .update(transactionFields)
      .eq("id", existingPayment.id);

    if (updateError) {
      // Pagamento já existe de fato no Mercado Pago — não reverter o
      // pedido para 'pending' aqui evitaria uma segunda tentativa
      // acidental sobre um pagamento que o MP já processou; erro fica
      // para investigação manual via provider_transaction_id no log.
      return jsonError("INTERNAL_ERROR", "Pagamento criado no Mercado Pago mas falhou ao atualizar transação.", {
        status: 500,
        details: updateError.message,
        requestId,
      });
    }
  } else {
    const { error: insertError } = await client.from("payment_transactions").insert(transactionFields);

    if (insertError) {
      return jsonError("INTERNAL_ERROR", "Pagamento criado no Mercado Pago mas falhou ao registrar transação.", {
        status: 500,
        details: insertError.message,
        requestId,
      });
    }
  }

  // Pagamento recusado/cancelado: devolve o pedido para 'pending' para
  // permitir nova tentativa com outro método (fluxo existente do
  // checkout_controller.submitPayment, não alterado por esta mudança).
  if (RETRYABLE_MP_STATUSES.has(payment.status)) {
    await revertOrderToPending();
  }
  // approved / pending / in_process / authorized: pedido permanece
  // 'processing' — mercadopago-webhook assume a transição para 'paid'.

  return jsonSuccess(
    {
      payment_id: payment.id,
      status: payment.status,
      status_detail: payment.status_detail,
      point_of_interaction: payment.point_of_interaction ?? null,
    },
    { status: 201, requestId },
  );
});