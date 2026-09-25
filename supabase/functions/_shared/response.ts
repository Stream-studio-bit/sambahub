// _shared/response.ts
// Envelope de resposta padrão de todas as Edge Functions do SambaHub
// (Prompt Mestre, item 10). Toda function deve responder usando
// jsonSuccess ou jsonError — nunca retornar JSON cru.

import { corsHeaders } from "./cors.ts";

export interface ApiError {
  code: string;
  message: string;
  details?: unknown;
}

export interface ApiEnvelope<T> {
  data: T | null;
  error: ApiError | null;
  meta: { request_id: string };
}

function jsonHeaders(): Record<string, string> {
  return {
    ...corsHeaders,
    "Content-Type": "application/json",
  };
}

/**
 * Resposta de sucesso. status default 200; use 201 para criação de recurso.
 */
export function jsonSuccess<T>(
  data: T,
  { status = 200, requestId }: { status?: number; requestId?: string } = {},
): Response {
  const body: ApiEnvelope<T> = {
    data,
    error: null,
    meta: { request_id: requestId ?? crypto.randomUUID() },
  };
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders() });
}

/**
 * Resposta de erro. status default 400; use 401/403/404/409/422/500 conforme o caso.
 * code deve ser um identificador estável em SCREAMING_SNAKE_CASE
 * (ex.: "PAYMENT_NOT_CONFIRMED", "PLATFORM_FEE_NOT_CONFIGURED"), nunca a
 * mensagem de erro bruta de uma exceção interna.
 */
export function jsonError(
  code: string,
  message: string,
  {
    status = 400,
    details = null,
    requestId,
  }: { status?: number; details?: unknown; requestId?: string } = {},
): Response {
  const body: ApiEnvelope<null> = {
    data: null,
    error: { code, message, details },
    meta: { request_id: requestId ?? crypto.randomUUID() },
  };
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders() });
}