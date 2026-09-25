// issue-tickets/index.ts
// CHANGELOG
// 2026-09-25: Corrigido bug confirmado no diagnóstico do check-in de
// catálogo — esta function gerava um ticket para TODO order_items do
// pedido, sem filtrar item_type. Um order_item do tipo 'catalog' tem
// campaign_product_id NULO (constraint order_items_product_ref_check
// exige isso), mas tickets.campaign_product_id é NOT NULL. O INSERT em
// lote falhava inteiro, e NENHUM ingresso era emitido em qualquer pedido
// que misturasse ingresso com item de catálogo (confirmado: já existiam
// 15 order_items tipo 'catalog' no banco).
// - A consulta a order_items agora também traz item_type.
// - Só entram no array `tickets` os itens com item_type === 'ticket'
//   (equivalente a campaign_product_id não nulo, mas o filtro é explícito
//   por item_type para não depender de um NULL implícito).
// - Itens 'catalog' do mesmo pedido são ignorados aqui de propósito: são
//   tratados pela function issue-catalog-redemptions, chamada
//   separadamente pelo mercadopago-webhook.
// - ORDER_EMPTY agora significa "pedido sem nenhum item tipo ticket", o
//   que é uma situação válida (pedido só com catálogo) — deixou de ser
//   erro. Retorna sucesso com tickets: [] nesse caso.
// - Nenhuma outra lógica alterada: idempotência por order_id (retorna
//   tickets existentes se já emitidos), autenticação server-to-server via
//   SUPABASE_SERVICE_ROLE_KEY, geração de código base64url de 18 bytes,
//   envelope de resposta { data, error, meta }.
//
// 2026-09-19: Corrigido BOOT_ERROR — o arquivo importava nomes que não existem em
// _shared (adminClient, json, errorResponse, options), então a função não iniciava
// e nenhum ingresso era emitido após o pagamento aprovado.
// Imports trocados pelos exports reais:
//   adminClient           -> getServiceRoleClient (_shared/supabase.ts)
//   json / errorResponse  -> jsonSuccess / jsonError (_shared/response.ts)
//   options()             -> handleCorsPreflight (_shared/cors.ts)
// - Resposta usa o envelope padrão { data, error, meta }. data passa a ser
//   { tickets, idempotent } (antes data era o array e idempotent ficava na raiz).
//   Único chamador conhecido é o mercadopago-webhook, que não lê a resposta.
// - Consulta do pedido: erro real do banco agora vira 500 (antes qualquer erro,
//   inclusive de conexão, virava "pedido não encontrado" 404). Pedido inexistente
//   continua 404 ORDER_NOT_FOUND.
// - JSON malformado retorna INVALID_JSON 400; order_id precisa ser string não vazia.
// - Autenticação preservada: somente chamada server-to-server com
//   Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>.
// - Lógica de emissão preservada: só pedidos 'paid'; se o pedido já tem tickets,
//   devolve os existentes (idempotent: true); um ticket por unidade de cada item;
//   código aleatório de 18 bytes em base64url; tenant_id, event_id (via campanha),
//   titular e e-mail vindos do pedido.
// LIMITAÇÃO CONHECIDA (não alterada): a idempotência é "consulta e depois insere",
// sem trava no banco. Duas chamadas simultâneas para o mesmo pedido podem emitir
// tickets em duplicidade (tickets não tem unique por pedido/produto).

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient } from "../_shared/supabase.ts";

function ticketCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(18));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as { message: unknown }).message);
  }
  return "Unknown error.";
}

Deno.serve(async (req: Request) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") return handleCorsPreflight();

  if (req.method !== "POST") {
    return jsonError("METHOD_NOT_ALLOWED", "Use POST.", { status: 405, requestId });
  }

  try {
    const authorization = req.headers.get("authorization");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceKey || authorization !== `Bearer ${serviceKey}`) {
      return jsonError("FORBIDDEN", "Acesso negado.", { status: 403, requestId });
    }

    let body: { order_id?: unknown };
    try {
      body = await req.json();
    } catch {
      return jsonError("INVALID_JSON", "Corpo da requisição inválido.", {
        status: 400,
        requestId,
      });
    }

    const orderId = typeof body.order_id === "string" ? body.order_id.trim() : "";
    if (!orderId) {
      return jsonError("VALIDATION_ERROR", "order_id é obrigatório.", {
        status: 400,
        requestId,
      });
    }

    const db = getServiceRoleClient();

    const { data: order, error: orderError } = await db
      .from("orders")
      .select("id, tenant_id, campaign_id, customer_name, customer_email, status")
      .eq("id", orderId)
      .maybeSingle();
    if (orderError) throw orderError;
    if (!order) {
      return jsonError("ORDER_NOT_FOUND", "Pedido não encontrado.", { status: 404, requestId });
    }
    if (order.status !== "paid") {
      return jsonError("ORDER_NOT_PAID", "Ingressos só podem ser emitidos para pedidos pagos.", {
        status: 409,
        requestId,
      });
    }

    const { data: existing, error: existingError } = await db
      .from("tickets")
      .select("id, code, event_id, campaign_product_id, holder_name, holder_email, status")
      .eq("order_id", order.id);
    if (existingError) throw existingError;
    if (existing && existing.length > 0) {
      return jsonSuccess({ tickets: existing, idempotent: true }, { requestId });
    }

    const { data: campaign, error: campaignError } = await db
      .from("campaigns")
      .select("event_id")
      .eq("id", order.campaign_id)
      .single();
    if (campaignError || !campaign) throw campaignError ?? new Error("Campaign not found.");

    // item_type incluído para filtrar: só itens 'ticket' geram registro em
    // `tickets`. Itens 'catalog' (campaign_product_id nulo) são tratados
    // por issue-catalog-redemptions, chamada separadamente.
    const { data: items, error: itemsError } = await db
      .from("order_items")
      .select("item_type, campaign_product_id, product_name, quantity")
      .eq("order_id", order.id);
    if (itemsError) throw itemsError;

    const ticketItems = (items ?? []).filter(
      (item) => item.item_type === "ticket" && item.campaign_product_id,
    );

    const tickets = ticketItems.flatMap((item) =>
      Array.from({ length: item.quantity as number }, () => ({
        tenant_id: order.tenant_id,
        order_id: order.id,
        event_id: campaign.event_id,
        campaign_product_id: item.campaign_product_id,
        code: ticketCode(),
        holder_name: order.customer_name,
        holder_email: order.customer_email,
        metadata: { product_name: item.product_name },
      }))
    );

    // Pedido só com itens de catálogo (sem nenhum ticket) é válido: não é
    // mais erro, e sim uma emissão vazia de ingressos.
    if (!tickets.length) {
      return jsonSuccess({ tickets: [], idempotent: false }, { requestId });
    }

    const { data: created, error: ticketError } = await db
      .from("tickets")
      .insert(tickets)
      .select("id, code, event_id, campaign_product_id, holder_name, holder_email, status, issued_at");
    if (ticketError) throw ticketError;

    return jsonSuccess({ tickets: created, idempotent: false }, { status: 201, requestId });
  } catch (error) {
    console.error(`[issue-tickets] ${requestId}`, error);
    return jsonError("TICKET_ISSUE_FAILED", "Não foi possível emitir os ingressos.", {
      status: 500,
      details: errorMessage(error),
      requestId,
    });
  }
});