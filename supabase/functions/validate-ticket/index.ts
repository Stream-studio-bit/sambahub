// validate-ticket/index.ts
// CHANGELOG
// 2026-09-25: Adicionada checagem de validade do evento — regra de negócio
// do usuário: "ingresso vale só para o próprio evento; se o usuário não
// compareceu, perdeu o ingresso, não vale para o próximo evento". Até
// aqui, um ticket 'issued' era aceito a qualquer momento, mesmo depois do
// evento ter terminado.
// - Busca events (status, starts_at, ends_at) pelo event_id já validado
//   como UUID. Evento inexistente -> reason 'event_not_found' (defensivo;
//   não deveria ocorrer, já que tickets.event_id tem FK para events).
// - Recusa com reason 'event_ended' quando: events.status = 'finished', OU
//   ends_at já passou, OU (ends_at nulo) starts_at + 24h já passou. A
//   janela de 24h para evento sem ends_at é uma folga assumida — avise se
//   quiser outro valor.
// - Checagem feita ANTES da busca do ticket: um evento encerrado recusa a
//   entrada mesmo que o ticket em si ainda esteja 'issued', sem precisar
//   tocar no ticket (ele continua 'issued' — não é marcado como usado nem
//   alterado de forma alguma quando a recusa é por evento encerrado).
// - Rejeição por evento encerrado é registrada em checkin_logs, mesmo
//   padrão dos demais reasons (result: 'rejected'), mas sem ticket_id
//   ainda resolvido (a busca do ticket só acontece depois) — por isso essa
//   rejeição específica NÃO grava em checkin_logs (a coluna ticket_id é
//   NOT NULL e exigiria uma consulta extra só para logar uma recusa cuja
//   causa é o evento, não o ticket). Mesmo comportamento que
//   ticket_not_found já tinha (não logado).
// - Nenhuma outra lógica alterada: autenticação, validação de entrada,
//   busca por code+event_id, tenant_mismatch, ticket_<status>, UPDATE
//   condicional issued->used, registros em checkin_logs para os demais
//   casos.
//
// 2026-09-19: Corrigido BOOT_ERROR — o arquivo importava nomes que não existem em
// _shared (adminClient, json, errorResponse, options, requireUser,
// requireTenantRole), então a função não iniciava e o check-in não funcionava.
// Imports trocados pelos exports reais:
//   adminClient                  -> getServiceRoleClient (_shared/supabase.ts)
//   json / errorResponse         -> jsonSuccess / jsonError (_shared/response.ts)
//   options()                    -> handleCorsPreflight (_shared/cors.ts)
//   requireUser                  -> auth.getUser(token) com o client service role
//                                   (mesmo padrão validado em provision-workspace)
//   requireTenantRole(owner,     -> assertCanOperateCheckin (_shared/auth.ts), que
//   admin, checkin)                 checa owner/admin/checkin via RPC can_operate_checkin
//                                   com o client escopado no JWT do usuário.
// - Resposta usa o envelope padrão { data, error, meta }. Os campos accepted,
//   reason e ticket continuam iguais, agora dentro de data.
// - Entrada validada: code, event_id e tenant_id precisam ser strings não vazias;
//   event_id e tenant_id precisam ser UUID (antes, um valor inválido virava erro
//   500 do PostgREST). JSON malformado retorna INVALID_JSON 400.
// - AuthError (401/403) é repassado com code e status próprios, em vez do
//   antigo mapeamento por texto da mensagem.
// - Falha ao gravar em checkin_logs agora é registrada em console.error (antes
//   era ignorada em silêncio); o resultado devolvido ao cliente não muda.
// - Lógica de negócio preservada: busca por code + event_id, tenant_mismatch,
//   ticket_<status> quando não está 'issued', UPDATE condicional issued -> used
//   (impede uso duplicado, resultado already_used) e registros em checkin_logs.

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient, getUserScopedClient } from "../_shared/supabase.ts";
import { AuthError, assertCanOperateCheckin, extractAuthHeader } from "../_shared/auth.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Folga assumida quando o evento não tem ends_at: aceita check-in até 24h
// depois de starts_at. Ajustável aqui sem precisar mexer no resto da lógica.
const NO_END_DATE_GRACE_HOURS = 24;

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

    let body: { code?: unknown; event_id?: unknown; tenant_id?: unknown };
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

    await assertCanOperateCheckin(getUserScopedClient(authorization), tenantId);

    // Validade do evento: um ingresso só vale enquanto o evento não
    // terminou. Checado antes de buscar o ticket, para recusar sem
    // precisar tocar em nada do ticket em si.
    const { data: event, error: eventError } = await db
      .from("events")
      .select("status, starts_at, ends_at")
      .eq("id", eventId)
      .maybeSingle();
    if (eventError) throw eventError;

    if (!event) {
      return jsonSuccess({ accepted: false, reason: "event_not_found" }, { requestId });
    }

    const now = new Date();
    const startsAt = new Date(event.starts_at);
    const endsAt = event.ends_at ? new Date(event.ends_at) : null;
    const graceDeadline = new Date(
      startsAt.getTime() + NO_END_DATE_GRACE_HOURS * 60 * 60 * 1000,
    );
    const eventEnded =
      event.status === "finished" ||
      (endsAt ? now > endsAt : now > graceDeadline);

    if (eventEnded) {
      return jsonSuccess({ accepted: false, reason: "event_ended" }, { requestId });
    }

    const { data: ticket, error: lookupError } = await db
      .from("tickets")
      .select("id, tenant_id, event_id, code, status, holder_name, holder_email")
      .eq("code", code)
      .eq("event_id", eventId)
      .maybeSingle();
    if (lookupError) throw lookupError;

    if (!ticket) {
      return jsonSuccess({ accepted: false, reason: "ticket_not_found" }, { requestId });
    }
    if (ticket.tenant_id !== tenantId) {
      return jsonSuccess({ accepted: false, reason: "tenant_mismatch" }, { requestId });
    }

    if (ticket.status !== "issued") {
      const { error: logError } = await db.from("checkin_logs").insert({
        tenant_id: tenantId,
        ticket_id: ticket.id,
        event_id: eventId,
        checked_by_user_id: userId,
        ticket_code: code,
        result: "rejected",
        reason: `ticket_${ticket.status}`,
      });
      if (logError) console.error(`[validate-ticket] ${requestId} checkin_logs`, logError);
      return jsonSuccess(
        { accepted: false, reason: `ticket_${ticket.status}`, ticket },
        { requestId },
      );
    }

    const { data: updated, error: updateError } = await db
      .from("tickets")
      .update({ status: "used", used_at: new Date().toISOString() })
      .eq("id", ticket.id)
      .eq("status", "issued")
      .select("id, code, status, used_at, holder_name, holder_email")
      .maybeSingle();
    if (updateError) throw updateError;
    if (!updated) {
      return jsonSuccess({ accepted: false, reason: "already_used" }, { requestId });
    }

    const { error: logError } = await db.from("checkin_logs").insert({
      tenant_id: tenantId,
      ticket_id: ticket.id,
      event_id: eventId,
      checked_by_user_id: userId,
      ticket_code: code,
      result: "accepted",
      reason: "valid_ticket",
    });
    if (logError) console.error(`[validate-ticket] ${requestId} checkin_logs`, logError);

    return jsonSuccess({ accepted: true, ticket: updated }, { requestId });
  } catch (error) {
    if (error instanceof AuthError) {
      return jsonError(error.code, error.message, { status: error.status, requestId });
    }
    console.error(`[validate-ticket] ${requestId}`, error);
    return jsonError("TICKET_VALIDATION_FAILED", "Não foi possível validar o ingresso.", {
      status: 500,
      details: errorMessage(error),
      requestId,
    });
  }
});