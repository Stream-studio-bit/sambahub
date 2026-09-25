// _shared/mercadopago.ts
// Chamadas à API do Mercado Pago (Marketplace 1:1 / OAuth / Checkout
// Transparente com Payment Brick) e validação de assinatura de webhook.
//
// CHANGELOG
// 2.0.0 (2026-09-21): Removida a dependência de MERCADOPAGO_ACCESS_TOKEN
//   global para pagamentos dos tenants. Removida createPreference()
//   (Checkout Pro) — não é mais usada no fluxo principal (Prompt Mestre,
//   item 4/6/14). Adicionados: getMercadoPagoConnection, isTokenExpiringSoon,
//   refreshAccessToken, getValidAccessToken (obtenção/renovação do OAuth
//   Access Token do vendedor a partir de mercadopago_connections).
//   fetchPayment foi substituída por fetchPaymentForTenant/
//   fetchPaymentWithAccessToken, que consultam sempre com a credencial do
//   vendedor. createPreference foi substituída por createTenantPayment,
//   que cria o pagamento via Payment Brick com application_fee. Mantidos
//   extractPaymentFee e verifyWebhookSignature sem alteração de lógica.
//   ATENÇÃO: mp-marketplace-oauth/index.ts (já entregue) deve ser conferido
//   separadamente — se ele grava/atualiza mercadopago_connections com nomes
//   de campo diferentes dos usados aqui, é preciso alinhar antes do deploy
//   de create-payment e do webhook.
// 1.0.0: versão original (Checkout Pro / Preferences API, token global).
//
// Algoritmo de assinatura do webhook confirmado na doc oficial (formato do
// header x-signature: "ts=<ts>,v1=<hash>", mais x-request-id e data.id) e no
// template manual de manifest, cruzado entre duas fontes independentes:
// manifest = "id:{data.id em lowercase};request-id:{x-request-id};ts:{ts};"
// hash = HMAC-SHA256(secret, manifest) em hex, comparado a v1.
// Fonte oficial: mercadopago.com.br/developers/pt/docs/checkout-pro-preferences/payment-notifications
// application_fee no Checkout Transparente/Marketplace 1:1 e refresh_token
// no endpoint /oauth/token: mercadopago.com.br/developers/pt/docs (Marketplace).

import { getServiceRoleClient } from "./supabase.ts";

const MERCADOPAGO_API_BASE = "https://api.mercadopago.com";

function getWebhookSecret(): string {
  const secret = Deno.env.get("MERCADOPAGO_WEBHOOK_SECRET");
  if (!secret) {
    throw new Error("MERCADOPAGO_WEBHOOK_SECRET não configurado no ambiente da Edge Function.");
  }
  return secret;
}

function getClientCredentials(): { clientId: string; clientSecret: string } {
  const clientId = Deno.env.get("MERCADOPAGO_CLIENT_ID");
  const clientSecret = Deno.env.get("MERCADOPAGO_CLIENT_SECRET");
  if (!clientId || !clientSecret) {
    throw new Error(
      "MERCADOPAGO_CLIENT_ID e MERCADOPAGO_CLIENT_SECRET são obrigatórias no ambiente da Edge Function.",
    );
  }
  return { clientId, clientSecret };
}

/**
 * Erro de domínio para tudo relacionado à conexão OAuth do tenant com o
 * Mercado Pago (ausente, expirada, falha ao renovar) ou a falhas da API do
 * Mercado Pago. `status` é o HTTP status que o handler da Edge Function deve
 * usar ao repassar o erro via jsonError.
 */
export class MercadoPagoError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, message: string, status = 502) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export interface MercadoPagoConnection {
  id: string;
  tenant_id: string;
  mp_user_id: string;
  access_token: string;
  refresh_token: string | null;
  token_expires_at: string | null;
  public_key: string | null;
  status: "connected" | "disconnected" | "expired" | "error";
  connected_at: string;
  updated_at: string;
  metadata: Record<string, unknown>;
}

/**
 * Busca a conexão Mercado Pago do tenant. Retorna null se o tenant nunca
 * conectou uma conta — quem chama decide se isso é erro (ex.: create-payment
 * deve recusar o pedido) ou estado normal (ex.: settings exibindo "não
 * conectado").
 */
export async function getMercadoPagoConnection(
  tenantId: string,
): Promise<MercadoPagoConnection | null> {
  const { data, error } = await getServiceRoleClient()
    .from("mercadopago_connections")
    .select("*")
    .eq("tenant_id", tenantId)
    .maybeSingle();

  if (error) {
    throw new MercadoPagoError(
      "MP_CONNECTION_LOOKUP_FAILED",
      `Falha ao buscar conexão Mercado Pago do tenant: ${error.message}`,
      500,
    );
  }

  return (data as MercadoPagoConnection | null) ?? null;
}

/**
 * true se o access_token expira dentro de `bufferSeconds` (default 5 min) ou
 * se token_expires_at não está preenchido (trata como expirado, por
 * segurança, em vez de assumir validade indefinida).
 */
export function isTokenExpiringSoon(
  connection: MercadoPagoConnection,
  bufferSeconds = 300,
): boolean {
  if (!connection.token_expires_at) return true;
  const expiresAt = new Date(connection.token_expires_at).getTime();
  if (Number.isNaN(expiresAt)) return true;
  return expiresAt - Date.now() <= bufferSeconds * 1000;
}

interface MercadoPagoOAuthTokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  public_key?: string;
  user_id?: number;
}

/**
 * Renova o access_token do tenant usando o refresh_token salvo, e persiste o
 * resultado em mercadopago_connections. Marca status = 'expired' quando o
 * Mercado Pago rejeita o refresh_token (invalid_grant — precisa de novo
 * OAuth completo) e status = 'error' para qualquer outra falha.
 */
export async function refreshAccessToken(
  connection: MercadoPagoConnection,
): Promise<MercadoPagoConnection> {
  if (!connection.refresh_token) {
    await getServiceRoleClient()
      .from("mercadopago_connections")
      .update({ status: "expired", updated_at: new Date().toISOString() })
      .eq("tenant_id", connection.tenant_id);
    throw new MercadoPagoError(
      "MP_CONNECTION_EXPIRED",
      "Conexão Mercado Pago sem refresh_token — é necessário reconectar.",
      409,
    );
  }

  const { clientId, clientSecret } = getClientCredentials();

  const response = await fetch(`${MERCADOPAGO_API_BASE}/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "refresh_token",
      refresh_token: connection.refresh_token,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    const newStatus = response.status === 400 ? "expired" : "error";
    await getServiceRoleClient()
      .from("mercadopago_connections")
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq("tenant_id", connection.tenant_id);
    throw new MercadoPagoError(
      newStatus === "expired" ? "MP_CONNECTION_EXPIRED" : "MP_REFRESH_FAILED",
      `Falha ao renovar token Mercado Pago do tenant (${response.status}): ${body}`,
      newStatus === "expired" ? 409 : 502,
    );
  }

  const tokenData = (await response.json()) as MercadoPagoOAuthTokenResponse;
  const nowIso = new Date().toISOString();
  const expiresAt = tokenData.expires_in
    ? new Date(Date.now() + tokenData.expires_in * 1000).toISOString()
    : null;

  const { data, error } = await getServiceRoleClient()
    .from("mercadopago_connections")
    .update({
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token ?? connection.refresh_token,
      token_expires_at: expiresAt,
      public_key: tokenData.public_key ?? connection.public_key,
      status: "connected",
      updated_at: nowIso,
    })
    .eq("tenant_id", connection.tenant_id)
    .select("*")
    .single();

  if (error) {
    throw new MercadoPagoError(
      "MP_CONNECTION_UPDATE_FAILED",
      `Token renovado no Mercado Pago mas falhou ao persistir: ${error.message}`,
      500,
    );
  }

  return data as MercadoPagoConnection;
}

/**
 * Retorna um access_token válido e pronto para uso server-side, renovando
 * automaticamente se estiver perto de expirar. É esta função que
 * create-payment e o webhook devem chamar — nunca ler access_token
 * diretamente de getMercadoPagoConnection sem passar por aqui.
 */
export async function getValidAccessToken(tenantId: string): Promise<string> {
  const connection = await getMercadoPagoConnection(tenantId);

  if (!connection || connection.status === "disconnected") {
    throw new MercadoPagoError(
      "MP_NOT_CONNECTED",
      "Este tenant ainda não conectou uma conta Mercado Pago.",
      409,
    );
  }

  if (connection.status === "error") {
    throw new MercadoPagoError(
      "MP_CONNECTION_ERROR",
      "Conexão Mercado Pago do tenant está em estado de erro — é necessário reconectar.",
      409,
    );
  }

  if (isTokenExpiringSoon(connection)) {
    const refreshed = await refreshAccessToken(connection);
    return refreshed.access_token;
  }

  return connection.access_token;
}

export interface CreateTenantPaymentParams {
  tenantId: string;
  orderId: string;
  transactionAmount: number;
  applicationFee: number;
  description: string;
  notificationUrl: string;
  idempotencyKey: string;
  paymentMethodId: string;
  token?: string;
  installments?: number;
  issuerId?: string;
  payer: {
    email: string;
    identification?: { type: string; number: string };
  };
}

export interface MercadoPagoPayment {
  id: number;
  status: string; // approved | pending | in_process | rejected | cancelled | refunded | charged_back | ...
  status_detail: string;
  transaction_amount: number;
  fee_details?: { type: string; amount: number }[];
  external_reference?: string;
  date_approved?: string | null;
  point_of_interaction?: {
    transaction_data?: { qr_code?: string; qr_code_base64?: string; ticket_url?: string };
  };
}

/**
 * Cria o pagamento (Checkout Transparente / Payment Brick) usando o OAuth
 * Access Token do vendedor do tenant, com application_fee = comissão
 * calculada no backend (Prompt Mestre, itens 5 e 6). external_reference é
 * sempre o order_id — quem chama nunca deve aceitar valor/comissão vindos do
 * frontend, apenas repassar o que já validou.
 */
export async function createTenantPayment(
  params: CreateTenantPaymentParams,
): Promise<MercadoPagoPayment> {
  const accessToken = await getValidAccessToken(params.tenantId);

  const response = await fetch(`${MERCADOPAGO_API_BASE}/v1/payments`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      "X-Idempotency-Key": params.idempotencyKey,
    },
    body: JSON.stringify({
      transaction_amount: params.transactionAmount,
      description: params.description,
      payment_method_id: params.paymentMethodId,
      token: params.token,
      installments: params.installments,
      issuer_id: params.issuerId,
      payer: params.payer,
      external_reference: params.orderId,
      notification_url: params.notificationUrl,
      application_fee: params.applicationFee,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new MercadoPagoError(
      "MP_PAYMENT_CREATE_FAILED",
      `Falha ao criar pagamento no Mercado Pago (${response.status}): ${body}`,
      502,
    );
  }

  return (await response.json()) as MercadoPagoPayment;
}

/**
 * Consulta um pagamento usando um access_token já resolvido — útil quando
 * quem chama (ex.: o webhook) já obteve o token do vendedor por outro
 * caminho e quer evitar uma segunda busca de conexão.
 */
export async function fetchPaymentWithAccessToken(
  paymentId: string,
  accessToken: string,
): Promise<MercadoPagoPayment> {
  const response = await fetch(`${MERCADOPAGO_API_BASE}/v1/payments/${paymentId}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new MercadoPagoError(
      "MP_PAYMENT_FETCH_FAILED",
      `Falha ao consultar pagamento ${paymentId} (${response.status}): ${body}`,
      502,
    );
  }

  return (await response.json()) as MercadoPagoPayment;
}

/**
 * Consulta um pagamento resolvendo o access_token do vendedor a partir do
 * tenant_id. É o caminho normal para create-payment (confirmação síncrona,
 * se precisar) e para o webhook, quando o tenant do pedido já foi
 * identificado via payment_transactions/orders.
 */
export async function fetchPaymentForTenant(
  tenantId: string,
  paymentId: string,
): Promise<MercadoPagoPayment> {
  const accessToken = await getValidAccessToken(tenantId);
  return fetchPaymentWithAccessToken(paymentId, accessToken);
}

/**
 * Soma as taxas do Mercado Pago retornadas em fee_details — nunca fixar um
 * percentual universal no código (Prompt Mestre, item 8).
 */
export function extractPaymentFee(payment: MercadoPagoPayment): number {
  if (!payment.fee_details?.length) return 0;
  return payment.fee_details.reduce((sum, fee) => sum + fee.amount, 0);
}

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Valida a assinatura x-signature de uma notificação webhook do Mercado Pago.
 * Retorna true/false — não lança exceção, para o handler decidir a resposta
 * HTTP (deve ser 401 em caso de assinatura inválida).
 */
export async function verifyWebhookSignature(params: {
  xSignature: string | null;
  xRequestId: string | null;
  dataId: string | null;
}): Promise<boolean> {
  const { xSignature, xRequestId, dataId } = params;
  if (!xSignature || !dataId) return false;

  let ts: string | null = null;
  let v1: string | null = null;
  for (const part of xSignature.split(",")) {
    const [key, value] = part.trim().split("=");
    if (key === "ts") ts = value;
    else if (key === "v1") v1 = value;
  }
  if (!ts || !v1) return false;

  const parts: string[] = [`id:${dataId.toLowerCase()}`];
  if (xRequestId) parts.push(`request-id:${xRequestId}`);
  parts.push(`ts:${ts}`);
  const manifest = parts.join(";") + ";";

  const expected = await hmacSha256Hex(getWebhookSecret(), manifest);
  return expected === v1;
}