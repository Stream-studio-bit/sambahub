// _shared/cors.ts
// Cabeçalhos CORS compartilhados por todas as Edge Functions do SambaHub.
// A rota pública (/c/{campaignSlug}) e o checkout rodam em Flutter Web servido
// pelo Firebase Hosting, além de chamadas autenticadas do app administrativo —
// por isso o wildcard de origem é aceito aqui; nenhuma credencial sensível
// trafega via header, e a autorização real é feita por RLS/JWT dentro de cada
// function, não pelo CORS.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-request-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Responde a requisições OPTIONS (preflight) do CORS.
 * Uso no topo de cada index.ts:
 *
 *   if (req.method === "OPTIONS") return handleCorsPreflight();
 */
export function handleCorsPreflight(): Response {
  return new Response("ok", { headers: corsHeaders });
}
