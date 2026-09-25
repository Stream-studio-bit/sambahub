// _shared/auth.ts
// Extração do usuário autenticado e checagem de role por tenant, usando as
// funções SQL já existentes (20260915000018_create_rls_helpers.sql):
// current_tenant_ids(), is_tenant_member(), has_tenant_role(),
// can_manage_tenant(), can_manage_finance(), can_operate_checkin().
//
// IMPORTANTE: essas funções SQL são `security definer` e leem `auth.uid()`
// internamente — por isso precisam ser chamadas com um client autenticado
// como o usuário (getUserScopedClient), nunca com o client de service role
// (onde auth.uid() seria null e toda checagem falharia silenciosamente).
//
// create-public-order e mercadopago-webhook NÃO usam este módulo: são
// endpoints públicos/server-to-server sem usuário autenticado.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export class AuthError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, message: string, status = 401) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export function extractAuthHeader(req: Request): string | null {
  return req.headers.get("Authorization") ?? req.headers.get("authorization");
}

/**
 * Retorna o id do usuário autenticado a partir do JWT no header Authorization.
 * Lança AuthError("UNAUTHENTICATED") se não houver sessão válida.
 */
export async function requireAuthenticatedUserId(
  userClient: SupabaseClient,
): Promise<string> {
  const { data, error } = await userClient.auth.getUser();

  if (error || !data.user) {
    throw new AuthError(
      "UNAUTHENTICATED",
      "Sessão inválida ou ausente.",
      401,
    );
  }

  return data.user.id;
}

async function callTenantCheck(
  userClient: SupabaseClient,
  fn: "is_tenant_member" | "can_manage_tenant" | "can_manage_finance" | "can_operate_checkin",
  tenantId: string,
): Promise<boolean> {
  const { data, error } = await userClient.rpc(fn, { target_tenant_id: tenantId });

  if (error) {
    throw new AuthError("AUTH_CHECK_FAILED", `Falha ao checar ${fn}: ${error.message}`, 500);
  }

  return data === true;
}

export async function assertTenantMember(
  userClient: SupabaseClient,
  tenantId: string,
): Promise<void> {
  const allowed = await callTenantCheck(userClient, "is_tenant_member", tenantId);
  if (!allowed) {
    throw new AuthError("NOT_TENANT_MEMBER", "Usuário não pertence a este tenant.", 403);
  }
}

export async function assertCanManageTenant(
  userClient: SupabaseClient,
  tenantId: string,
): Promise<void> {
  const allowed = await callTenantCheck(userClient, "can_manage_tenant", tenantId);
  if (!allowed) {
    throw new AuthError(
      "TENANT_MANAGEMENT_FORBIDDEN",
      "Requer papel owner ou admin no tenant.",
      403,
    );
  }
}

export async function assertCanManageFinance(
  userClient: SupabaseClient,
  tenantId: string,
): Promise<void> {
  const allowed = await callTenantCheck(userClient, "can_manage_finance", tenantId);
  if (!allowed) {
    throw new AuthError(
      "FINANCE_ACCESS_FORBIDDEN",
      "Requer papel owner, admin ou finance no tenant.",
      403,
    );
  }
}

export async function assertCanOperateCheckin(
  userClient: SupabaseClient,
  tenantId: string,
): Promise<void> {
  const allowed = await callTenantCheck(userClient, "can_operate_checkin", tenantId);
  if (!allowed) {
    throw new AuthError(
      "CHECKIN_ACCESS_FORBIDDEN",
      "Requer papel owner, admin ou checkin no tenant.",
      403,
    );
  }
}

/**
 * has_tenant_role aceita uma lista de roles — usar quando a checagem não se
 * encaixa em nenhum dos helpers específicos acima (ex.: 'producer' isolado).
 */
export async function assertHasTenantRole(
  userClient: SupabaseClient,
  tenantId: string,
  allowedRoles: string[],
): Promise<void> {
  const { data, error } = await userClient.rpc("has_tenant_role", {
    target_tenant_id: tenantId,
    allowed_roles: allowedRoles,
  });

  if (error) {
    throw new AuthError("AUTH_CHECK_FAILED", `Falha ao checar has_tenant_role: ${error.message}`, 500);
  }

  if (data !== true) {
    throw new AuthError(
      "TENANT_ROLE_FORBIDDEN",
      `Requer um dos papéis: ${allowedRoles.join(", ")}.`,
      403,
    );
  }
}