// redeem-catalog-item/index.ts
// CHANGELOG
// 2026-09-25: Criada. Faz para produtos do catálogo o que validate-ticket
// faz para ingressos: recebe o código lido pelo check-in, autentica e
// autoriza (mesmo padrão de validate-ticket: assertCanOperateCheckin via
// RPC can_operate_checkin, cliente escopado no JWT do usuário), e dá baixa
// de forma atômica no saldo de retirada.
// - NÃO mexe em catalog_products.stock_quantity: a baixa de estoque já
//   aconteceu na compra (fn_reserve_order_stock_and_create). Esta function
//   só controla catalog_redemptions.quantity_redeemed (saldo de RETIRADA
//   de um item já pago).
// - Baixa por unidade informada (quantity, padrão 1) — decisão do usuário:
//   "pode retirar uma por vez, retirar um por vez, ou todos de uma vez".
// - UPDATE condicional único garante atomicidade (mesma estratégia do
//   UPDATE issued->used em validate-ticket): só aplica se status='active',
//   dentro do prazo (expires_at > now()) e há saldo suficiente. Nenhuma
//   consulta seguida de update separado — evita corrida de duas leituras
//   simultâneas do mesmo QR.
// - code é único globalmente (catalog_redemptions.code), mas a busca ainda
//   filtra por tenant_id e event_id recebidos, para nunca dar baixa em
//   redemption de outro tenant/evento por engano.
// - Toda tentativa com o registro encontrado (aceita ou recusada) é
//   gravada em catalog_redemption_logs. Tentativa com código inexistente
//   não é logada (não há redemption_id para referenciar), mesmo
//   comportamento de ticket_not_found em validate-ticket.
// - Entrada validada: code, event_id e tenant_id não vazios; event_id e
//   tenant_id precisam ser UUID; quantity, se enviado, precisa ser inteiro
//   positivo (padrão 1).

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient, getUserScopedClient } from "../_shared/supabase.ts";
import { AuthError, assertCanOperateCheckin, extractAuthHeader } from "../_shared/auth.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
    const authorization = extractAuthHeader(req);
    if (!authorization?.startsWith("Bearer ")) {
      return jsonError("UNAUTHENTICATED", "Autenticação obrigatória.", {
        status: 401,
        requestId,
      });
    }

    const db = getServiceRoleClient();
    const { data: authData, error: authError } = await db.auth.getUser(
      authorization.substring(7),
    );
    if (authError || !authData.user) {
      return jsonError("UNAUTHENTICATED", "Sessão inválida ou ausente.", {
        status: 401,
        requestId,
      });
    }
    const userId = authData.user.id;

    let body: {
      code?: unknown;
      event_id?: unknown;
      tenant_id?: unknown;
      quantity?: unknown;
    };
    try {
      body = await req.json();
    } catch {
      return jsonError("INVALID_JSON", "Corpo da requisição inválido.", {
        status: 400,
        requestId,
      });
    }

    const code = typeof body.code === "string" ? body.code.trim() : "";
    const eventId = typeof body.event_id === "string" ? body.event_id.trim() : "";
    const tenantId = typeof body.tenant_id === "string" ? body.tenant_id.trim() : "";
    const quantity =
      body.quantity === undefined || body.quantity === null
        ? 1
        : Number(body.quantity);

    if (!code || !eventId || !tenantId) {
      return jsonError("VALIDATION_ERROR", "code, event_id e tenant_id são obrigatórios.", {
        status: 400,
        requestId,
      });
    }
    if (!UUID_PATTERN.test(eventId) || !UUID_PATTERN.test(tenantId)) {
      return jsonError("VALIDATION_ERROR", "event_id e tenant_id devem ser UUIDs válidos.", {
        status: 400,
        requestId,
      });
    }
    if (!Number.isInteger(quantity) || quantity <= 0) {
      return jsonError("VALIDATION_ERROR", "quantity deve ser um número inteiro positivo.", {
        status: 400,
        requestId,
      });
    }

    await assertCanOperateCheckin(getUserScopedClient(authorization), tenantId);

    const { data: redemption, error: lookupError } = await db
      .from("catalog_redemptions")
      .select("id, tenant_id, event_id, catalog_product_id, quantity_total, quantity_redeemed, status, expires_at")
      .eq("code", code)
      .maybeSingle();
    if (lookupError) throw lookupError;

    if (!redemption) {
      return jsonSuccess({ accepted: false, reason: "redemption_not_found" }, { requestId });
    }
    if (redemption.tenant_id !== tenantId) {
      return jsonSuccess({ accepted: false, reason: "tenant_mismatch" }, { requestId });
    }
    if (redemption.event_id !== eventId) {
      return jsonSuccess({ accepted: false, reason: "event_mismatch" }, { requestId });
    }

    const now = new Date();
    const isExpired =
      redemption.status === "expired" ||
      (redemption.status === "active" && new Date(redemption.expires_at) <= now);
    const remainingBalance = redemption.quantity_total - redemption.quantity_redeemed;

    let rejectReason: string | null = null;
    if (redemption.status === "cancelled") {
      rejectReason = "redemption_cancelled";
    } else if (isExpired) {
      rejectReason = "redemption_expired";
    } else if (redemption.status === "completed" || remainingBalance <= 0) {
      rejectReason = "redemption_completed";
    } else if (quantity > remainingBalance) {
      rejectReason = "insufficient_balance";
    }

    if (rejectReason) {
      const { error: logError } = await db.from("catalog_redemption_logs").insert({
        tenant_id: tenantId,
        redemption_id: redemption.id,
        event_id: eventId,
        checked_by_user_id: userId,
        quantity,
        result: "rejected",
        reason: rejectReason,
      });
      if (logError) console.error(`[redeem-catalog-item] ${requestId} log`, logError);

      return jsonSuccess(
        { accepted: false, reason: rejectReason, remaining_balance: Math.max(remainingBalance, 0) },
        { requestId },
      );
    }

    // UPDATE condicional único: reavalia status/prazo/saldo na hora da
    // escrita, com a linha travada pelo próprio UPDATE — evita corrida
    // entre duas leituras simultâneas do mesmo código.
    const { data: updated, error: updateError } = await db
      .from("catalog_redemptions")
      .update({
        quantity_redeemed: redemption.quantity_redeemed + quantity,
        status:
          redemption.quantity_redeemed + quantity >= redemption.quantity_total
            ? "completed"
            : "active",
      })
      .eq("id", redemption.id)
      .eq("status", "active")
      .gt("expires_at", now.toISOString())
      .lte("quantity_redeemed", redemption.quantity_total - quantity)
      .select("id, catalog_product_id, quantity_total, quantity_redeemed, status")
      .maybeSingle();
    if (updateError) throw updateError;

    if (!updated) {
      // Perdeu a corrida (outro operador deu baixa entre a leitura e o
      // UPDATE). Não loga como accepted: a causa exata já mudou.
      const { error: logError } = await db.from("catalog_redemption_logs").insert({
        tenant_id: tenantId,
        redemption_id: redemption.id,
        event_id: eventId,
        checked_by_user_id: userId,
        quantity,
        result: "rejected",
        reason: "concurrent_update",
      });
      if (logError) console.error(`[redeem-catalog-item] ${requestId} log`, logError);

      return jsonSuccess(
        { accepted: false, reason: "concurrent_update" },
        { requestId },
      );
    }

    const { error: logError } = await db.from("catalog_redemption_logs").insert({
      tenant_id: tenantId,
      redemption_id: redemption.id,
      event_id: eventId,
      checked_by_user_id: userId,
      quantity,
      result: "accepted",
      reason: "valid_redemption",
    });
    if (logError) console.error(`[redeem-catalog-item] ${requestId} log`, logError);

    const { data: product } = await db
      .from("catalog_products")
      .select("name")
      .eq("id", updated.catalog_product_id)
      .maybeSingle();

    return jsonSuccess(
      {
        accepted: true,
        product_name: product?.name ?? null,
        quantity_redeemed_now: quantity,
        remaining_balance: updated.quantity_total - updated.quantity_redeemed,
        status: updated.status,
      },
      { requestId },
    );
  } catch (error) {
    if (error instanceof AuthError) {
      return jsonError(error.code, error.message, { status: error.status, requestId });
    }
    console.error(`[redeem-catalog-item] ${requestId}`, error);
    return jsonError("CATALOG_REDEMPTION_FAILED", "Não foi possível processar a retirada.", {
      status: 500,
      details: errorMessage(error),
      requestId,
    });
  }
});