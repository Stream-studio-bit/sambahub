// _shared/idempotency.ts
// Helpers de idempotência para as Edge Functions que criam registros
// financeiros (orders, payment_transactions). Usa as constraints reais do
// banco: unique(tenant_id, idempotency_key) em orders e payment_transactions,
// e unique(provider, provider_transaction_id) em payment_transactions.
//
// Toda function que cria um registro financeiro deve checar idempotência
// ANTES do insert e retornar o registro existente em vez de duplicar, mesmo
// que o client reenvie a mesma requisição (retry de rede, duplo clique, etc.).

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Busca um registro existente por (tenant_id, idempotency_key) numa tabela
 * que tenha essa constraint única (orders, payment_transactions).
 * Retorna null se não existir — não lança erro nesse caso.
 */
export async function findByIdempotencyKey<T = Record<string, unknown>>(
  client: SupabaseClient,
  table: "orders" | "payment_transactions",
  tenantId: string,
  idempotencyKey: string,
): Promise<T | null> {
  const { data, error } = await client
    .from(table)
    .select("*")
    .eq("tenant_id", tenantId)
    .eq("idempotency_key", idempotencyKey)
    .maybeSingle();

  if (error) {
    throw new Error(`Falha ao checar idempotência em ${table}: ${error.message}`);
  }

  return (data as T | null) ?? null;
}

/**
 * Busca uma payment_transaction existente por (provider, provider_transaction_id).
 * Usado pelo mercadopago-webhook para não duplicar processamento quando o
 * Mercado Pago reenvia a mesma notificação (ele reenvia com backoff se não
 * receber 200/201 a tempo — ver Prompt Mestre / documentação oficial).
 */
export async function findPaymentByProviderTransactionId<T = Record<string, unknown>>(
  client: SupabaseClient,
  provider: string,
  providerTransactionId: string,
): Promise<T | null> {
  const { data, error } = await client
    .from("payment_transactions")
    .select("*")
    .eq("provider", provider)
    .eq("provider_transaction_id", providerTransactionId)
    .maybeSingle();

  if (error) {
    throw new Error(
      `Falha ao checar idempotência de payment_transactions por provider_transaction_id: ${error.message}`,
    );
  }

  return (data as T | null) ?? null;
}