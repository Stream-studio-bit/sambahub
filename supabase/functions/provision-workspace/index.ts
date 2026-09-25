// provision-workspace/index.ts
// CHANGELOG
// 2026-09-22: Slug do tenant deixou de receber sufixo aleatório de 8
// caracteres do crypto.randomUUID(). Agora `slug: baseSlug` (apenas o
// resultado de slugify(name)). Sem verificação de unicidade adicional —
// se a coluna slug tiver constraint UNIQUE, nomes que gerem o mesmo
// baseSlug vão colidir e o insert em `tenants` vai falhar (error tratado
// no catch como WORKSPACE_PROVISION_FAILED).
// 2026-09-18: Corrigido BOOT_ERROR ("The requested module '../_shared/supabase.ts'
// does not provide an export named 'adminClient'"). O arquivo importava nomes que
// não existem em _shared. Imports trocados pelos exports reais:
//   adminClient                  -> getServiceRoleClient (_shared/supabase.ts)
//   json / errorResponse         -> jsonSuccess / jsonError (_shared/response.ts)
//   options()                    -> handleCorsPreflight (_shared/cors.ts)
// - Resposta passa a usar o envelope padrão { data, error, meta }. Como antes,
//   o tenant_id continua em data.tenant_id (o Flutter lê data['data']['tenant_id']);
//   o flag `idempotent` agora fica dentro de data (antes ficava na raiz).
// - Autenticação mantida como no original: JWT do header Authorization validado
//   com auth.getUser(token). Não usa requireAuthenticatedUserId de _shared/auth.ts
//   (helper ainda não exercitado por nenhuma function em produção).
// - Corpo inválido (JSON malformado) agora retorna INVALID_JSON 400 em vez de 500.
// - slugify: o corte de 56 caracteres agora acontece ANTES de remover hífens das
//   pontas; antes, o corte podia deixar hífen no fim e gerar "--" no slug final.
// - Erros do PostgREST (objetos, não instâncias de Error) agora têm a mensagem
//   preservada em details; o code é estável (WORKSPACE_PROVISION_FAILED).
// - Lógica de negócio preservada: idempotência por membership ativa, criação de
//   tenant + membership, rollback do tenant se a membership falhar, role
//   'producer' para producer/group e 'owner' para os demais.

import { handleCorsPreflight } from "../_shared/cors.ts";
import { jsonError, jsonSuccess } from "../_shared/response.ts";
import { getServiceRoleClient } from "../_shared/supabase.ts";
import { extractAuthHeader } from "../_shared/auth.ts";

function slugify(value: string): string {
  const slug = value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .slice(0, 56)
    .replace(/^-+|-+$/g, "");
  return slug || "sambahub";
}

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

    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return jsonError("INVALID_JSON", "Corpo da requisição inválido.", {
        status: 400,
        requestId,
      });
    }

    const name = typeof body.name === "string" ? body.name.trim() : "";
    const profileType = typeof body.profile_type === "string" ? body.profile_type : "venue";
    if (!name) {
      return jsonError("VALIDATION_ERROR", "O nome da organização é obrigatório.", {
        status: 400,
        requestId,
      });
    }

    const existing = await db
      .from("tenant_memberships")
      .select("tenant_id, tenants(id, name, slug)")
      .eq("user_id", userId)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();
    if (existing.error) throw existing.error;
    if (existing.data) {
      return jsonSuccess(
        {
          tenant_id: existing.data.tenant_id,
          tenant: existing.data.tenants,
          idempotent: true,
        },
        { requestId },
      );
    }

    const baseSlug = slugify(name);
    const tenant = await db
      .from("tenants")
      .insert({ name, slug: baseSlug })
      .select("id, name, slug")
      .single();
    if (tenant.error || !tenant.data) {
      throw tenant.error ?? new Error("Unable to create workspace.");
    }

    const membership = await db
      .from("tenant_memberships")
      .insert({
        tenant_id: tenant.data.id,
        user_id: userId,
        role: profileType === "producer" || profileType === "group" ? "producer" : "owner",
        status: "active",
      })
      .select("tenant_id, role")
      .single();
    if (membership.error) {
      await db.from("tenants").delete().eq("id", tenant.data.id);
      throw membership.error;
    }

    return jsonSuccess(
      {
        tenant_id: tenant.data.id,
        tenant: tenant.data,
        role: membership.data.role,
        idempotent: false,
      },
      { status: 201, requestId },
    );
  } catch (error) {
    console.error(`[provision-workspace] ${requestId}`, error);
    return jsonError(
      "WORKSPACE_PROVISION_FAILED",
      "Não foi possível criar a organização.",
      { status: 500, details: errorMessage(error), requestId },
    );
  }
});