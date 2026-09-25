// maintenance-tasks/index.ts
// CHANGELOG
// 2026-09-25: Criada. Ponto de entrada único para as duas rotinas de
// manutenção que o diagnóstico do check-in de catálogo exigiu:
// - fn_release_abandoned_order_stock(): cancela pedidos 'pending' sem
//   pagamento aprovado há mais de 15 minutos e devolve o estoque reservado
//   (corrige o vazamento confirmado no diagnóstico: o webhook, de
//   propósito, nunca cancela pedido rejeitado/cancelado — só devolve para
//   'pending', para permitir nova tentativa de pagamento — então um pedido
//   nunca mais pago prendia estoque para sempre).
// - fn_expire_stale_catalog_redemptions(): marca como 'expired' os
//   resgates de catálogo cujo prazo de 15 dias já passou e ainda têm
//   saldo. Não é estritamente necessária para a correção funcionar (a
//   própria redeem-catalog-item já confere o prazo a cada chamada), mas
//   mantém o status correto no dashboard mesmo sem nenhuma tentativa de
//   retirada.
//
// IMPORTANTE — infraestrutura fora do meu alcance: este banco não tem a
// extensão pg_cron instalada (confirmado no diagnóstico), então esta
// function PRECISA ser chamada por um agendador externo ao Supabase — cron
// do seu provedor de hospedagem, GitHub Actions com schedule, ou qualquer
// serviço de cron HTTP. Configure-o para fazer POST periódico (sugestão:
// a cada 5–10 minutos) para esta function, com o header Authorization
// abaixo. Isso não pode ser configurado por mim.
//
// Autenticação: mesmo padrão server-to-server de issue-tickets — só aceita
// Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>. Não é acessível por
// usuário autenticado comum.

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient } from "../_shared/supabase.ts";

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

    const db = getServiceRoleClient();

    const { data: releasedCount, error: releaseError } = await db.rpc(
      "fn_release_abandoned_order_stock",
    );
    if (releaseError) throw releaseError;

    const { data: expiredCount, error: expireError } = await db.rpc(
      "fn_expire_stale_catalog_redemptions",
    );
    if (expireError) throw expireError;

    return jsonSuccess(
      {
        orders_stock_released: releasedCount ?? 0,
        catalog_redemptions_expired: expiredCount ?? 0,
      },
      { requestId },
    );
  } catch (error) {
    console.error(`[maintenance-tasks] ${requestId}`, error);
    return jsonError("MAINTENANCE_TASK_FAILED", "Falha ao executar rotinas de manutenção.", {
      status: 500,
      details: errorMessage(error),
      requestId,
    });
  }
});