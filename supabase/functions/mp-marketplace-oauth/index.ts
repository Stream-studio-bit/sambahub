// supabase/functions/mp-marketplace-oauth/index.ts
//
// CHANGELOG
// 2026-09-23  Callback: o redirect para MERCADOPAGO_OAUTH_RETURN_URL agora leva
//             também `tenant=<id>`, tirado do `state` já verificado, para o app
//             cair em /settings?tenant=<id> em vez de uma página em branco.
//             Como a URL de retorno é fixa e o tenant muda por conexão, ele
//             só pode vir daqui. Só é acrescentado depois de verifyState()
//             validar a assinatura; erros anteriores (missing_params,
//             state inválido) redirecionam sem tenant. Se o usuário cancelar
//             no Mercado Pago (access_denied), o state devolvido é verificado
//             de forma tolerante só para recuperar o tenant.
// 2026-09-21  Criação. OAuth Mercado Pago (Marketplace 1:1) por tenant.
//             Ações (POST, autenticadas, owner/admin ativo do tenant):
//               - connect     -> devolve authorization_url (o Flutter abre a URL)
//               - status      -> connected | disconnected | expired | error
//               - refresh     -> renova access_token via refresh_token
//               - disconnect  -> remove a conexão (tokens apagados)
//             Callback (GET, sem JWT — chamado pelo redirect do Mercado Pago):
//               - valida `state` assinado (HMAC-SHA256), troca `code` por token
//                 em POST /oauth/token e faz upsert em mercadopago_connections.
//
// Regras de segurança:
//   - access_token / refresh_token / client_secret nunca saem desta function
//     (nem em resposta HTTP, nem em log).
//   - tenant_id do body NUNCA autoriza nada: a autorização vem do JWT + linha
//     ativa em tenant_memberships (role owner/admin).
//   - No callback o tenant e o usuário vêm do `state` assinado, e a membership
//     é revalidada antes de gravar tokens.
//
// Env obrigatórias: MERCADOPAGO_CLIENT_ID, MERCADOPAGO_CLIENT_SECRET,
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY.
// Env opcionais:
//   MERCADOPAGO_OAUTH_RETURN_URL   URL do app para onde o callback redireciona
//                                  (recebe ?mp_oauth=success|error&reason=...).
//   MERCADOPAGO_OAUTH_REDIRECT_URI Sobrescreve o redirect_uri (default:
//                                  {SUPABASE_URL}/functions/v1/mp-marketplace-oauth).
//                                  Deve ser IDÊNTICO ao "Redirect URL" do app no
//                                  painel do Mercado Pago.
//
// Documentação: mercadopago.com.br/developers/pt/docs/security/oauth/creation
//               mercadopago.com.br/developers/pt/docs/security/oauth/renewal

import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";
import {
  getServiceRoleClient,
  getUserScopedClient,
} from "../_shared/supabase.ts";
import {
  assertCanManageTenant,
  AuthError,
  extractAuthHeader,
  requireAuthenticatedUserId,
} from "../_shared/auth.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const MP_AUTHORIZATION_URL = "https://auth.mercadopago.com/authorization";
const MP_TOKEN_URL = "https://api.mercadopago.com/oauth/token";
const STATE_TTL_MS = 10 * 60 * 1000; // o `code` do MP vale 10 minutos
const HTTP_TIMEOUT_MS = 15_000;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type ConnectionStatus = "connected" | "disconnected" | "expired" | "error";

// ---------------------------------------------------------------------------
// Erros
// ---------------------------------------------------------------------------

class ActionError extends Error {
  readonly code: string;
  readonly status: number;
  constructor(code: string, message: string, status = 400) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

/** Erro do endpoint /oauth/token. `code` é o campo `error` da resposta (ex.: invalid_grant). */
class MpOAuthError extends Error {
  readonly code: string;
  readonly httpStatus: number;
  constructor(code: string, httpStatus: number) {
    super(`Mercado Pago OAuth: ${code} (HTTP ${httpStatus})`);
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

// ---------------------------------------------------------------------------
// Ambiente
// ---------------------------------------------------------------------------

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new ActionError(
      "SERVER_MISCONFIGURED",
      `${name} não configurado no ambiente da Edge Function.`,
      500,
    );
  }
  return value;
}

function getRedirectUri(): string {
  const override = Deno.env.get("MERCADOPAGO_OAUTH_REDIRECT_URI");
  if (override) return override;
  return `${requireEnv("SUPABASE_URL")}/functions/v1/mp-marketplace-oauth`;
}

// ---------------------------------------------------------------------------
// Resposta HTTP
// ---------------------------------------------------------------------------

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorResponse(error: unknown): Response {
  if (error instanceof AuthError || error instanceof ActionError) {
    return jsonResponse(
      { ok: false, error: { code: error.code, message: error.message } },
      error.status,
    );
  }
  if (error instanceof MpOAuthError) {
    console.error("[mp-marketplace-oauth]", error.message);
    return jsonResponse(
      {
        ok: false,
        error: {
          code: "MERCADOPAGO_OAUTH_FAILED",
          message: "Falha na comunicação com o Mercado Pago.",
        },
      },
      502,
    );
  }
  console.error(
    "[mp-marketplace-oauth] erro inesperado:",
    error instanceof Error ? error.message : "desconhecido",
  );
  return jsonResponse(
    {
      ok: false,
      error: { code: "INTERNAL_ERROR", message: "Erro interno." },
    },
    500,
  );
}

// ---------------------------------------------------------------------------
// state assinado (stateless): base64url(payload) + "." + base64url(HMAC-SHA256)
// ---------------------------------------------------------------------------

interface StatePayload {
  v: 1;
  t: string; // tenant_id
  u: string; // user_id
  n: string; // nonce
  exp: number; // epoch ms
}

function toBase64Url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/") +
    "=".repeat((4 - (value.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function getStateKey(): Promise<CryptoKey> {
  // Chave derivada do client secret com prefixo de domínio, para não reutilizar
  // o segredo "cru" como chave de HMAC.
  const secret = `mp-oauth-state-v1:${requireEnv("MERCADOPAGO_CLIENT_SECRET")}`;
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

async function createState(tenantId: string, userId: string): Promise<string> {
  const payload: StatePayload = {
    v: 1,
    t: tenantId,
    u: userId,
    n: toBase64Url(crypto.getRandomValues(new Uint8Array(16))),
    exp: Date.now() + STATE_TTL_MS,
  };
  const body = toBase64Url(new TextEncoder().encode(JSON.stringify(payload)));
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      await getStateKey(),
      new TextEncoder().encode(body),
    ),
  );
  return `${body}.${toBase64Url(signature)}`;
}

async function verifyState(state: string): Promise<StatePayload> {
  const invalid = () =>
    new ActionError("INVALID_STATE", "State inválido ou expirado.", 400);

  const parts = state.split(".");
  if (parts.length !== 2) throw invalid();
  const [body, signature] = parts;

  let signatureBytes: ReturnType<typeof fromBase64Url>;
  try {
    signatureBytes = fromBase64Url(signature);
  } catch {
    throw invalid();
  }

  // crypto.subtle.verify compara em tempo constante.
  const valid = await crypto.subtle.verify(
    "HMAC",
    await getStateKey(),
    signatureBytes,
    new TextEncoder().encode(body),
  );
  if (!valid) throw invalid();

  let payload: StatePayload;
  try {
    payload = JSON.parse(new TextDecoder().decode(fromBase64Url(body)));
  } catch {
    throw invalid();
  }

  if (
    payload.v !== 1 ||
    typeof payload.t !== "string" || !UUID_RE.test(payload.t) ||
    typeof payload.u !== "string" || !UUID_RE.test(payload.u) ||
    typeof payload.exp !== "number" || payload.exp < Date.now()
  ) {
    throw invalid();
  }
  return payload;
}

// ---------------------------------------------------------------------------
// Autorização
// ---------------------------------------------------------------------------

/**
 * Valida diretamente em tenant_memberships (service role):
 * tenant_id + user_id + status = 'active' + role in ('owner','admin').
 */
async function assertActiveOwnerOrAdmin(
  service: SupabaseClient,
  tenantId: string,
  userId: string,
): Promise<void> {
  const { data, error } = await service
    .from("tenant_memberships")
    .select("role")
    .eq("tenant_id", tenantId)
    .eq("user_id", userId)
    .eq("status", "active")
    .in("role", ["owner", "admin"])
    .limit(1);

  if (error) {
    throw new ActionError(
      "AUTH_CHECK_FAILED",
      "Falha ao validar permissão no tenant.",
      500,
    );
  }
  if (!data || data.length === 0) {
    throw new AuthError(
      "TENANT_MANAGEMENT_FORBIDDEN",
      "Requer papel owner ou admin ativo no tenant.",
      403,
    );
  }
}

// ---------------------------------------------------------------------------
// Mercado Pago /oauth/token
// ---------------------------------------------------------------------------

interface MpTokenResponse {
  access_token: string;
  token_type?: string;
  expires_in: number;
  scope?: string;
  user_id: number | string;
  refresh_token?: string;
  public_key?: string;
  live_mode?: boolean;
}

async function requestToken(
  params: Record<string, string>,
): Promise<MpTokenResponse> {
  let response: Response;
  try {
    response = await fetch(MP_TOKEN_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        client_id: requireEnv("MERCADOPAGO_CLIENT_ID"),
        client_secret: requireEnv("MERCADOPAGO_CLIENT_SECRET"),
        ...params,
      }),
      signal: AbortSignal.timeout(HTTP_TIMEOUT_MS),
    });
  } catch {
    throw new MpOAuthError("network_error", 0);
  }

  // O corpo NUNCA é logado (pode conter tokens); só o campo `error`.
  // deno-lint-ignore no-explicit-any
  const json: any = await response.json().catch(() => null);

  if (!response.ok) {
    throw new MpOAuthError(
      typeof json?.error === "string" ? json.error : "token_request_failed",
      response.status,
    );
  }

  if (
    !json || typeof json.access_token !== "string" ||
    json.user_id === undefined || json.user_id === null ||
    typeof json.expires_in !== "number"
  ) {
    throw new MpOAuthError("invalid_token_response", response.status);
  }

  return json as MpTokenResponse;
}

function expiresAtIso(expiresInSeconds: number): string {
  return new Date(Date.now() + expiresInSeconds * 1000).toISOString();
}

// ---------------------------------------------------------------------------
// Persistência / renovação
// ---------------------------------------------------------------------------

async function saveConnection(
  service: SupabaseClient,
  tenantId: string,
  connectedBy: string,
  token: MpTokenResponse,
): Promise<void> {
  const nowIso = new Date().toISOString();
  const { error } = await service.from("mercadopago_connections").upsert(
    {
      tenant_id: tenantId,
      mp_user_id: String(token.user_id),
      access_token: token.access_token,
      refresh_token: token.refresh_token ?? null,
      token_expires_at: expiresAtIso(token.expires_in),
      public_key: token.public_key ?? null,
      status: "connected",
      connected_at: nowIso,
      metadata: {
        scope: token.scope ?? null,
        live_mode: token.live_mode ?? null,
        token_type: token.token_type ?? null,
        connected_by: connectedBy,
      },
    },
    { onConflict: "tenant_id" },
  );

  if (error) {
    throw new ActionError(
      "CONNECTION_SAVE_FAILED",
      "Falha ao salvar a conexão Mercado Pago.",
      500,
    );
  }
}

interface ConnectionRow {
  id: string;
  mp_user_id: string;
  status: ConnectionStatus;
  connected_at: string;
  token_expires_at: string | null;
  refresh_token: string | null;
}

async function readConnection(
  service: SupabaseClient,
  tenantId: string,
): Promise<ConnectionRow | null> {
  const { data, error } = await service
    .from("mercadopago_connections")
    .select(
      "id, mp_user_id, status, connected_at, token_expires_at, refresh_token",
    )
    .eq("tenant_id", tenantId)
    .limit(1);

  if (error) {
    throw new ActionError(
      "CONNECTION_READ_FAILED",
      "Falha ao consultar a conexão Mercado Pago.",
      500,
    );
  }
  return (data && data.length > 0) ? (data[0] as ConnectionRow) : null;
}

async function setStatus(
  service: SupabaseClient,
  connectionId: string,
  status: ConnectionStatus,
): Promise<void> {
  await service.from("mercadopago_connections").update({ status }).eq(
    "id",
    connectionId,
  );
}

/**
 * Renova o access_token com o refresh_token (o MP devolve um refresh_token
 * novo a cada renovação; o antigo deixa de valer). Usa compare-and-set no
 * refresh_token para não sobrescrever uma renovação concorrente.
 */
async function refreshConnection(
  service: SupabaseClient,
  tenantId: string,
): Promise<ConnectionRow> {
  const row = await readConnection(service, tenantId);
  if (!row) {
    throw new ActionError(
      "NOT_CONNECTED",
      "Tenant sem conexão Mercado Pago.",
      404,
    );
  }
  if (!row.refresh_token) {
    await setStatus(service, row.id, "expired");
    return { ...row, status: "expired" };
  }

  let token: MpTokenResponse;
  try {
    token = await requestToken({
      grant_type: "refresh_token",
      refresh_token: row.refresh_token,
    });
  } catch (error) {
    if (!(error instanceof MpOAuthError)) throw error;

    // Renovação concorrente: se o refresh_token mudou, outra chamada já renovou.
    const current = await readConnection(service, tenantId);
    if (current && current.refresh_token !== row.refresh_token) return current;

    if (error.code === "invalid_grant") {
      await setStatus(service, row.id, "expired");
      return { ...row, status: "expired" };
    }
    if (error.httpStatus >= 400 && error.httpStatus < 500 && error.httpStatus !== 429) {
      await setStatus(service, row.id, "error");
      return { ...row, status: "error" };
    }
    throw error; // falha transitória (rede, 429, 5xx): não altera o status
  }

  const update: Record<string, unknown> = {
    access_token: token.access_token,
    refresh_token: token.refresh_token ?? row.refresh_token,
    token_expires_at: expiresAtIso(token.expires_in),
    status: "connected",
  };
  if (token.public_key) update.public_key = token.public_key;

  const { data, error } = await service
    .from("mercadopago_connections")
    .update(update)
    .eq("id", row.id)
    .eq("refresh_token", row.refresh_token)
    .select("id");

  if (error) {
    throw new ActionError(
      "CONNECTION_SAVE_FAILED",
      "Falha ao salvar o token renovado.",
      500,
    );
  }
  if (!data || data.length === 0) {
    // Outra renovação gravou primeiro; usa o estado atual.
    const current = await readConnection(service, tenantId);
    if (current) return current;
  }

  const refreshed = await readConnection(service, tenantId);
  if (!refreshed) {
    throw new ActionError("NOT_CONNECTED", "Tenant sem conexão Mercado Pago.", 404);
  }
  return refreshed;
}

// ---------------------------------------------------------------------------
// Resposta de status (nunca inclui tokens)
// ---------------------------------------------------------------------------

function maskMpUserId(mpUserId: string): string {
  return mpUserId.length <= 4 ? "••••" : `••••${mpUserId.slice(-4)}`;
}

function statusPayload(row: ConnectionRow | null) {
  if (!row) {
    return {
      ok: true,
      status: "disconnected" as ConnectionStatus,
      mp_user_id: null,
      connected_at: null,
    };
  }
  return {
    ok: true,
    status: row.status,
    mp_user_id: maskMpUserId(row.mp_user_id),
    connected_at: row.connected_at,
  };
}

// ---------------------------------------------------------------------------
// Ações (POST)
// ---------------------------------------------------------------------------

async function handleAction(req: Request): Promise<Response> {
  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    throw new ActionError("INVALID_BODY", "Corpo JSON inválido.", 400);
  }

  const action = body?.action;
  const tenantId = body?.tenant_id;
  if (typeof action !== "string") {
    throw new ActionError("INVALID_ACTION", "Campo `action` obrigatório.", 400);
  }
  if (typeof tenantId !== "string" || !UUID_RE.test(tenantId)) {
    throw new ActionError("INVALID_TENANT_ID", "tenant_id inválido.", 400);
  }

  // Autenticação + autorização (owner/admin ativo do tenant).
  const userClient = getUserScopedClient(extractAuthHeader(req));
  const userId = await requireAuthenticatedUserId(userClient);
  await assertCanManageTenant(userClient, tenantId);
  const service = getServiceRoleClient();
  await assertActiveOwnerOrAdmin(service, tenantId, userId);

  switch (action) {
    case "connect": {
      const url = new URL(MP_AUTHORIZATION_URL);
      url.searchParams.set("client_id", requireEnv("MERCADOPAGO_CLIENT_ID"));
      url.searchParams.set("response_type", "code");
      url.searchParams.set("platform_id", "mp");
      url.searchParams.set("state", await createState(tenantId, userId));
      url.searchParams.set("redirect_uri", getRedirectUri());
      return jsonResponse({ ok: true, authorization_url: url.toString() });
    }

    case "status": {
      let row = await readConnection(service, tenantId);
      if (
        row && row.status === "connected" && row.token_expires_at &&
        new Date(row.token_expires_at).getTime() <= Date.now()
      ) {
        row = await refreshConnection(service, tenantId);
      }
      return jsonResponse(statusPayload(row));
    }

    case "refresh": {
      const row = await refreshConnection(service, tenantId);
      return jsonResponse(statusPayload(row));
    }

    case "disconnect": {
      const { error } = await service
        .from("mercadopago_connections")
        .delete()
        .eq("tenant_id", tenantId);
      if (error) {
        throw new ActionError(
          "DISCONNECT_FAILED",
          "Falha ao desconectar o Mercado Pago.",
          500,
        );
      }
      return jsonResponse(statusPayload(null));
    }

    default:
      throw new ActionError("INVALID_ACTION", "Ação desconhecida.", 400);
  }
}

// ---------------------------------------------------------------------------
// Callback (GET) — redirect do Mercado Pago, sem JWT
// ---------------------------------------------------------------------------

function callbackResponse(
  result: "success" | "error",
  reason?: string,
  tenantId?: string,
): Response {
  const returnUrl = Deno.env.get("MERCADOPAGO_OAUTH_RETURN_URL");
  if (returnUrl) {
    try {
      const target = new URL(returnUrl);
      target.searchParams.set("mp_oauth", result);
      if (reason) target.searchParams.set("reason", reason);
      if (tenantId) target.searchParams.set("tenant", tenantId);
      return new Response(null, {
        status: 302,
        headers: { Location: target.toString() },
      });
    } catch {
      // MERCADOPAGO_OAUTH_RETURN_URL inválida: cai no texto simples abaixo.
    }
  }
  // O gateway do Supabase serve respostas de Edge Functions como text/plain.
  const message = result === "success"
    ? "Conta Mercado Pago conectada. Você já pode fechar esta janela."
    : `Não foi possível conectar o Mercado Pago (${reason ?? "erro"}).`;
  return new Response(message, {
    status: result === "success" ? 200 : 400,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

async function handleCallback(req: Request): Promise<Response> {
  const params = new URL(req.url).searchParams;
  // Só preenchido depois que o `state` assinado for verificado.
  let tenantId: string | undefined;

  try {
    if (params.get("error")) {
      // Usuário cancelou no Mercado Pago. Se o state vier e for válido,
      // recupera o tenant para voltar à tela certa; se não, segue sem ele.
      const cancelledState = params.get("state");
      if (cancelledState) {
        try {
          tenantId = (await verifyState(cancelledState)).t;
        } catch {
          // state ausente/inválido/expirado: redireciona sem tenant.
        }
      }
      return callbackResponse("error", "access_denied", tenantId);
    }

    const code = params.get("code");
    const state = params.get("state");
    if (!code || !state) return callbackResponse("error", "missing_params");

    const payload = await verifyState(state);
    tenantId = payload.t;

    // Revalida a permissão no momento do callback (o usuário pode ter perdido
    // o papel desde o `connect`).
    const service = getServiceRoleClient();
    await assertActiveOwnerOrAdmin(service, payload.t, payload.u);

    const token = await requestToken({
      grant_type: "authorization_code",
      code,
      redirect_uri: getRedirectUri(),
    });

    await saveConnection(service, payload.t, payload.u, token);
    return callbackResponse("success", undefined, tenantId);
  } catch (error) {
    if (error instanceof ActionError || error instanceof AuthError) {
      console.error("[mp-marketplace-oauth] callback:", error.code);
      return callbackResponse("error", error.code.toLowerCase(), tenantId);
    }
    if (error instanceof MpOAuthError) {
      console.error("[mp-marketplace-oauth] callback:", error.message);
      return callbackResponse("error", error.code, tenantId);
    }
    console.error(
      "[mp-marketplace-oauth] callback: erro inesperado:",
      error instanceof Error ? error.message : "desconhecido",
    );
    return callbackResponse("error", "internal_error", tenantId);
  }
}

// ---------------------------------------------------------------------------
// Entrypoint
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return handleCorsPreflight();

  try {
    if (req.method === "GET") return await handleCallback(req);
    if (req.method === "POST") return await handleAction(req);
    return jsonResponse(
      {
        ok: false,
        error: { code: "METHOD_NOT_ALLOWED", message: "Método não permitido." },
      },
      405,
    );
  } catch (error) {
    return errorResponse(error);
  }
});