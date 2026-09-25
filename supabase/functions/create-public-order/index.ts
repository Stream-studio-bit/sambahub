// create-public-order/index.ts
// Cria um pedido público a partir de /c/{campaignSlug} sem exigir conta.
// Chamada por: features/campaigns/data/campaigns_repository.dart::createPublicOrder
// e features/checkout/data/checkout_repository.dart::createOrder (CheckoutRequest).
//
// Responsabilidade única desta function: validar a campanha, reservar estoque
// em transação atômica (fn_reserve_order_stock_and_create) e criar o pedido
// com status 'pending'. A criação do pagamento no Mercado Pago continua
// sendo responsabilidade de create-payment, chamada separadamente (Prompt
// Mestre, item 10, lista as duas como functions distintas) — isso não muda.
//
// CHANGELOG
// 2026-09-21: Marketplace 1:1 + Payment Brick (Prompt Mestre, item 7) expõe
//   um problema de sequência: o Payment Brick precisa da public_key do
//   tenant para SE RENDERIZAR, o que acontece ANTES do cliente preencher o
//   formulário de pagamento — ou seja, antes de create-payment ser chamado
//   (create-payment só é chamado com os dados que o Brick coletou). Não
//   existe endpoint público (sem JWT) que devolva a public_key de um tenant
//   a partir de uma campanha; mp-marketplace-oauth/status exige
//   autenticação de owner/admin, incompatível com checkout público.
//   Removido o campo `payment_url` (sempre null aqui, resquício do Checkout
//   Pro — a function nunca de fato usava isso) e adicionado
//   `mercadopago_public_key`: lido de mercadopago_connections (coluna já
//   usada por mp-marketplace-oauth/index.ts e _shared/mercadopago.ts —
//   pública por natureza, ao contrário de access_token/refresh_token, que
//   esta function jamais toca). Só é devolvida quando status = 'connected';
//   caso contrário vem null e o Flutter deve tratar como "pagamento
//   indisponível" em vez de tentar renderizar o Brick. Aplicado tanto no
//   caminho novo (RPC) quanto nos dois caminhos de replay idempotente
//   (idempotency_key já existente e corrida 23505), para o cliente sempre
//   saber se pode prosseguir independente de qual caminho respondeu.
//   Resto do fluxo (validação de payload, catalog_products, RPC
//   fn_reserve_order_stock_and_create, tratamento de erros) mantido sem
//   alteração de lógica.
// 2026-09-20: Catálogo (catalog_products) passa a poder entrar no mesmo
// pedido dos ingressos (campaign_products) — decisão de modelagem (Opção A):
// order_items ganhou item_type + catalog_product_id (ver migração SQL
// 2026_09_20_catalog_in_public_checkout.sql), e
// fn_reserve_order_stock_and_create agora ramifica por item_type.
// - Novo campo opcional no payload: catalog_products (mesmo formato de
//   products: Record<productId, quantity>).
// - `products` continua existindo com o mesmo formato/semântica de antes
//   (ingressos) — retrocompatível com clientes que ainda não mandam
//   catalog_products (nesse caso o campo é tratado como {} e o pedido só tem
//   itens tipo 'ticket', igual ao comportamento anterior).
// - `items` internamente ganhou o campo item_type ('ticket' | 'catalog'),
//   repassado para a RPC via p_items. A validação de quantidade e as
//   mensagens de erro (PRODUCT_NOT_FOUND, INSUFFICIENT_STOCK, etc.)
//   continuam as mesmas, agora cobrindo os dois tipos.

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient } from "../_shared/supabase.ts";
import { findByIdempotencyKey } from "../_shared/idempotency.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

interface CreatePublicOrderPayload {
  campaign_id?: string;
  customer_name?: string;
  customer_email?: string;
  customer_phone?: string;
  products?: Record<string, number>;
  catalog_products?: Record<string, number>;
  idempotency_key?: string;
}

interface OrderRecord {
  id: string;
  status: string;
  gross_amount: number | string;
}

/**
 * public_key do tenant no Mercado Pago, para o Flutter inicializar o Payment
 * Brick — só quando a conexão está 'connected'. Nunca lê/retorna
 * access_token ou refresh_token (esta function não deve ter motivo para
 * sequer selecioná-los).
 */
async function getTenantPublicKey(
  client: SupabaseClient,
  tenantId: string,
): Promise<string | null> {
  const { data, error } = await client
    .from("mercadopago_connections")
    .select("public_key, status")
    .eq("tenant_id", tenantId)
    .maybeSingle();

  if (error || !data) return null;
  if (data.status !== "connected") return null;
  return (data.public_key as string | null) ?? null;
}

Deno.serve(async (req: Request) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") return handleCorsPreflight();

  if (req.method !== "POST") {
    return jsonError("METHOD_NOT_ALLOWED", "Use POST.", { status: 405, requestId });
  }

  let payload: CreatePublicOrderPayload;
  try {
    payload = await req.json();
  } catch {
    return jsonError("INVALID_JSON", "Corpo da requisição inválido.", { status: 400, requestId });
  }

  const campaignId = payload.campaign_id?.trim();
  const customerName = payload.customer_name?.trim();
  const customerEmail = payload.customer_email?.trim().toLowerCase();
  const customerPhone = payload.customer_phone?.trim();
  const idempotencyKey = payload.idempotency_key?.trim();
  const products = payload.products ?? {};
  const catalogProducts = payload.catalog_products ?? {};

  if (!campaignId || !customerName || !customerEmail || !customerPhone || !idempotencyKey) {
    return jsonError(
      "VALIDATION_ERROR",
      "campaign_id, customer_name, customer_email, customer_phone e idempotency_key são obrigatórios.",
      { status: 400, requestId },
    );
  }

  if (Object.keys(products).length === 0 && Object.keys(catalogProducts).length === 0) {
    return jsonError("VALIDATION_ERROR", "O pedido precisa de ao menos um produto.", {
      status: 400,
      requestId,
    });
  }

  const items: { product_id: string; item_type: "ticket" | "catalog"; quantity: number }[] = [];

  for (const [productId, quantity] of Object.entries(products)) {
    if (!Number.isInteger(quantity) || quantity <= 0) {
      return jsonError(
        "VALIDATION_ERROR",
        `Quantidade inválida para o produto ${productId}.`,
        { status: 400, requestId },
      );
    }
    items.push({ product_id: productId, item_type: "ticket", quantity });
  }

  for (const [productId, quantity] of Object.entries(catalogProducts)) {
    if (!Number.isInteger(quantity) || quantity <= 0) {
      return jsonError(
        "VALIDATION_ERROR",
        `Quantidade inválida para o produto ${productId}.`,
        { status: 400, requestId },
      );
    }
    items.push({ product_id: productId, item_type: "catalog", quantity });
  }

  const client = getServiceRoleClient();

  const { data: campaign, error: campaignError } = await client
    .from("campaigns")
    .select("id, tenant_id, status, starts_at, ends_at")
    .eq("id", campaignId)
    .maybeSingle();

  if (campaignError) {
    return jsonError("INTERNAL_ERROR", "Falha ao consultar a campanha.", {
      status: 500,
      details: campaignError.message,
      requestId,
    });
  }

  if (!campaign) {
    return jsonError("CAMPAIGN_NOT_FOUND", "Campanha não encontrada.", { status: 404, requestId });
  }

  const now = new Date();
  const startsAt = campaign.starts_at ? new Date(campaign.starts_at) : null;
  const endsAt = campaign.ends_at ? new Date(campaign.ends_at) : null;
  const withinWindow = (!startsAt || startsAt <= now) && (!endsAt || endsAt >= now);

  if (campaign.status !== "published" || !withinWindow) {
    return jsonError("CAMPAIGN_NOT_AVAILABLE", "Esta campanha não está disponível para pedidos.", {
      status: 404,
      requestId,
    });
  }

  const tenantId = campaign.tenant_id as string;

  const existingOrder = await findByIdempotencyKey<OrderRecord>(
    client,
    "orders",
    tenantId,
    idempotencyKey,
  );

  if (existingOrder) {
    const publicKey = await getTenantPublicKey(client, tenantId);
    return jsonSuccess(
      {
        order_id: existingOrder.id,
        status: existingOrder.status,
        gross_amount: existingOrder.gross_amount,
        mercadopago_public_key: publicKey,
      },
      { requestId },
    );
  }

  const { data: rpcRows, error: rpcError } = await client.rpc(
    "fn_reserve_order_stock_and_create",
    {
      p_tenant_id: tenantId,
      p_campaign_id: campaignId,
      p_customer_name: customerName,
      p_customer_email: customerEmail,
      p_customer_phone: customerPhone,
      p_idempotency_key: idempotencyKey,
      p_items: items,
    },
  );

  if (rpcError) {
    const message = rpcError.message ?? "";

    // Corrida rara: dois requests com a mesma idempotency_key bateram na
    // constraint unique(tenant_id, idempotency_key) ao mesmo tempo. Trata
    // como replay idempotente em vez de erro.
    if (rpcError.code === "23505") {
      const raceOrder = await findByIdempotencyKey<OrderRecord>(
        client,
        "orders",
        tenantId,
        idempotencyKey,
      );
      if (raceOrder) {
        const publicKey = await getTenantPublicKey(client, tenantId);
        return jsonSuccess(
          {
            order_id: raceOrder.id,
            status: raceOrder.status,
            gross_amount: raceOrder.gross_amount,
            mercadopago_public_key: publicKey,
          },
          { requestId },
        );
      }
    }

    if (message.includes("PRODUCT_NOT_FOUND")) {
      return jsonError("PRODUCT_NOT_FOUND", "Um ou mais produtos do pedido não existem ou estão inativos.", {
        status: 404,
        requestId,
      });
    }
    if (message.includes("INSUFFICIENT_STOCK")) {
      return jsonError("INSUFFICIENT_STOCK", "Estoque insuficiente para um dos produtos.", {
        status: 409,
        requestId,
      });
    }
    if (message.includes("INVALID_QUANTITY") || message.includes("EMPTY_ORDER")) {
      return jsonError("VALIDATION_ERROR", "Quantidade de itens inválida.", {
        status: 400,
        requestId,
      });
    }
    if (message.includes("INVALID_ITEM_TYPE")) {
      return jsonError("VALIDATION_ERROR", "Tipo de item inválido no pedido.", {
        status: 400,
        requestId,
      });
    }

    return jsonError("INTERNAL_ERROR", "Falha ao criar o pedido.", {
      status: 500,
      details: message,
      requestId,
    });
  }

  const created = Array.isArray(rpcRows) ? rpcRows[0] : rpcRows;
  const publicKey = await getTenantPublicKey(client, tenantId);

  return jsonSuccess(
    {
      order_id: created.order_id,
      status: "pending",
      gross_amount: created.gross_amount,
      mercadopago_public_key: publicKey,
    },
    { status: 201, requestId },
  );
});