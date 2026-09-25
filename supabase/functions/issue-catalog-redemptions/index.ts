// issue-catalog-redemptions/index.ts
// CHANGELOG
// 2026-09-25 (v2): Código de resgate passa a ter prefixo "P-" — decisão do
// usuário: o app deve distinguir QR de produto e de ingresso pelo próprio
// texto lido, sem tentar os dois endpoints em sequência. Ingresso
// (tickets.code, gerado por issue-tickets) continua sem prefixo. O
// qr_service.dart (arquivo seguinte) decide validate-ticket vs
// redeem-catalog-item olhando esse prefixo antes de chamar o servidor.
//
// 2026-09-25: Criada. Mesmo papel de issue-tickets, mas para order_items do
// tipo 'catalog' (produtos do catálogo comprados junto ou separado de
// ingresso). Decisão do usuário: um código de resgate POR ITEM DE PEDIDO
// (catalog_redemptions.order_item_id é unique), não um código por pedido —
// cliente pode comprar combo + cerveja + caipirinha no mesmo pedido e
// retirar cada um em momentos diferentes.
// - Chamada pelo mercadopago-webhook junto com issue-tickets, na branch de
//   pagamento aprovado (isApproving). Mesmo padrão de autenticação
//   server-to-server via SUPABASE_SERVICE_ROLE_KEY.
// - Idempotente: se já existem catalog_redemptions para os order_items
//   'catalog' deste pedido, devolve os existentes em vez de duplicar
//   (a constraint unique(order_item_id) impediria duplicata de qualquer
//   forma, mas a checagem evita erro 23505 em retry).
// - expires_at = orders.paid_at + 15 dias corridos (regra de negócio do
//   usuário: produto não retirado em 15 dias fica bloqueado/expired —
//   controlado por fn_expire_stale_catalog_redemptions e reforçado na
//   própria leitura, em redeem-catalog-item).
// - NÃO mexe em catalog_products.stock_quantity: a baixa de estoque já
//   aconteceu na criação do pedido (fn_reserve_order_stock_and_create).
//   Esta function só cria o controle de saldo de RETIRADA.
// - Pedido sem nenhum order_item tipo 'catalog' é caso válido (pedido só
//   de ingresso): devolve redemptions: [] idempotent: false, sem erro.

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient } from "../_shared/supabase.ts";

const REDEMPTION_VALIDITY_DAYS = 15;

// Prefixo "P-" distingue este código do de ingresso (tickets.code, sem
// prefixo) para o app decidir qual endpoint chamar sem tentar os dois.
function redemptionCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(18));
  const random = btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
  return `P-${random}`;
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
      .select("id, tenant_id, campaign_id, status, paid_at")
      .eq("id", orderId)
      .maybeSingle();
    if (orderError) throw orderError;
    if (!order) {
      return jsonError("ORDER_NOT_FOUND", "Pedido não encontrado.", { status: 404, requestId });
    }
    if (order.status !== "paid") {
      return jsonError(
        "ORDER_NOT_PAID",
        "Resgates de catálogo só podem ser emitidos para pedidos pagos.",
        { status: 409, requestId },
      );
    }
    if (!order.paid_at) {
      return jsonError(
        "ORDER_MISSING_PAID_AT",
        "Pedido pago sem data de pagamento registrada.",
        { status: 409, requestId },
      );
    }

    const { data: catalogItems, error: itemsError } = await db
      .from("order_items")
      .select("id, catalog_product_id, quantity")
      .eq("order_id", order.id)
      .eq("item_type", "catalog");
    if (itemsError) throw itemsError;

    // Pedido sem item de catálogo é caso válido (só ingresso).
    if (!catalogItems || catalogItems.length === 0) {
      return jsonSuccess({ redemptions: [], idempotent: false }, { requestId });
    }

    const orderItemIds = catalogItems.map((item) => item.id);

    const { data: existing, error: existingError } = await db
      .from("catalog_redemptions")
      .select("id, order_item_id, catalog_product_id, event_id, code, quantity_total, quantity_redeemed, status, expires_at")
      .in("order_item_id", orderItemIds);
    if (existingError) throw existingError;
    if (existing && existing.length > 0) {
      return jsonSuccess({ redemptions: existing, idempotent: true }, { requestId });
    }

    const { data: campaign, error: campaignError } = await db
      .from("campaigns")
      .select("event_id")
      .eq("id", order.campaign_id)
      .single();
    if (campaignError || !campaign) throw campaignError ?? new Error("Campaign not found.");

    const expiresAt = new Date(order.paid_at);
    expiresAt.setUTCDate(expiresAt.getUTCDate() + REDEMPTION_VALIDITY_DAYS);

    const redemptions = catalogItems.map((item) => ({
      tenant_id: order.tenant_id,
      order_item_id: item.id,
      catalog_product_id: item.catalog_product_id,
      event_id: campaign.event_id,
      code: redemptionCode(),
      quantity_total: item.quantity,
      expires_at: expiresAt.toISOString(),
    }));

    const { data: created, error: insertError } = await db
      .from("catalog_redemptions")
      .insert(redemptions)
      .select("id, order_item_id, catalog_product_id, event_id, code, quantity_total, quantity_redeemed, status, expires_at");
    if (insertError) throw insertError;

    return jsonSuccess({ redemptions: created, idempotent: false }, { status: 201, requestId });
  } catch (error) {
    console.error(`[issue-catalog-redemptions] ${requestId}`, error);
    return jsonError(
      "CATALOG_REDEMPTION_ISSUE_FAILED",
      "Não foi possível emitir os resgates de catálogo.",
      { status: 500, details: errorMessage(error), requestId },
    );
  }
});