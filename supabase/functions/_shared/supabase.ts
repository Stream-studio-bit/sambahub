// _shared/supabase.ts
// Client Supabase com service role, para uso exclusivo dentro das Edge
// Functions. NUNCA importar este módulo em código que roda no Flutter/Web —
// SUPABASE_SERVICE_ROLE_KEY ignora RLS.
//
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são injetadas automaticamente pelo
// runtime de Edge Functions em produção; localmente, `supabase functions
// serve` também as injeta a partir do projeto linkado (não precisam estar no
// supabase/functions/.env).

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

let cachedClient: SupabaseClient | null = null;

/**
 * Retorna um client singleton com service role. Lança erro claro se as
 * variáveis de ambiente obrigatórias não estiverem configuradas, em vez de
 * falhar silenciosamente numa chamada de rede posterior.
 */
export function getServiceRoleClient(): SupabaseClient {
  if (cachedClient) return cachedClient;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são obrigatórias no ambiente da Edge Function.",
    );
  }

  cachedClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return cachedClient;
}

/**
 * Client com o JWT do usuário autenticado (quando presente no header
 * Authorization), para operações que devem respeitar RLS em vez de
 * bypassá-la com service role — ex.: checagens de leitura antes de decidir
 * se a mutação é permitida.
 */
export function getUserScopedClient(authHeader: string | null): SupabaseClient {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !anonKey) {
    throw new Error(
      "SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórias no ambiente da Edge Function.",
    );
  }

  return createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: authHeader ? { Authorization: authHeader } : {},
    },
  });
}