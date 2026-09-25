-- SambaHub / Supabase RLS
-- Esta migration deve ser executada depois das tabelas de negócio e antes das
-- funções financeiras. Nenhuma política confia em valores enviados pelo cliente.

create or replace function public.current_tenant_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select tm.tenant_id
  from public.tenant_memberships tm
  where tm.user_id = auth.uid()
    and tm.status = 'active';
$$;

create or replace function public.is_tenant_member(target_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tenant_memberships tm
    where tm.tenant_id = target_tenant_id
      and tm.user_id = auth.uid()
      and tm.status = 'active'
  );
$$;

create or replace function public.has_tenant_role(
  target_tenant_id uuid,
  allowed_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tenant_memberships tm
    where tm.tenant_id = target_tenant_id
      and tm.user_id = auth.uid()
      and tm.status = 'active'
      and tm.role = any(allowed_roles)
  );
$$;

create or replace function public.can_manage_tenant(target_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_tenant_role(
    target_tenant_id,
    array['owner', 'admin']::text[]
  );
$$;

create or replace function public.can_manage_finance(target_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_tenant_role(
    target_tenant_id,
    array['owner', 'admin', 'finance']::text[]
  );
$$;

create or replace function public.can_operate_checkin(target_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_tenant_role(
    target_tenant_id,
    array['owner', 'admin', 'checkin']::text[]
  );
$$;

revoke all on function public.current_tenant_ids() from public;
revoke all on function public.is_tenant_member(uuid) from public;
revoke all on function public.has_tenant_role(uuid, text[]) from public;
revoke all on function public.can_manage_tenant(uuid) from public;
revoke all on function public.can_manage_finance(uuid) from public;
revoke all on function public.can_operate_checkin(uuid) from public;

grant execute on function public.current_tenant_ids() to authenticated;
grant execute on function public.is_tenant_member(uuid) to authenticated;
grant execute on function public.has_tenant_role(uuid, text[]) to authenticated;
grant execute on function public.can_manage_tenant(uuid) to authenticated;
grant execute on function public.can_manage_finance(uuid) to authenticated;
grant execute on function public.can_operate_checkin(uuid) to authenticated;

-- Ative RLS em todas as tabelas protegidas.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'tenants', 'tenant_memberships', 'groups', 'venues',
    'events', 'campaigns', 'campaign_products', 'orders', 'order_items',
    'payment_transactions', 'tickets', 'checkin_logs', 'group_contracts',
    'settlements', 'audit_logs'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
  end loop;
end;
$$;

-- Profiles: o usuário acessa somente o próprio perfil.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
for select to authenticated
using (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Tenants e memberships: somente membros ativos; gestão reservada a owner/admin.
drop policy if exists tenants_select_member on public.tenants;
create policy tenants_select_member on public.tenants
for select to authenticated
using (public.is_tenant_member(id));

drop policy if exists tenants_update_manager on public.tenants;
create policy tenants_update_manager on public.tenants
for update to authenticated
using (public.can_manage_tenant(id))
with check (public.can_manage_tenant(id));

drop policy if exists memberships_select_member on public.tenant_memberships;
create policy memberships_select_member on public.tenant_memberships
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists memberships_manage on public.tenant_memberships;
create policy memberships_manage on public.tenant_memberships
for all to authenticated
using (public.can_manage_tenant(tenant_id))
with check (public.can_manage_tenant(tenant_id));

-- Entidades operacionais: membros podem ler; owner/admin/producer podem alterar.
drop policy if exists groups_member_select on public.groups;
create policy groups_member_select on public.groups
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists groups_manager_write on public.groups;
create policy groups_manager_write on public.groups
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]));

drop policy if exists venues_member_select on public.venues;
create policy venues_member_select on public.venues
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists venues_manager_write on public.venues;
create policy venues_manager_write on public.venues
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]));

drop policy if exists events_member_select on public.events;
create policy events_member_select on public.events
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists events_manager_write on public.events;
create policy events_manager_write on public.events
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]));

-- Público: somente campanhas publicadas e produtos ativos dentro do período.
drop policy if exists campaigns_public_select on public.campaigns;
create policy campaigns_public_select on public.campaigns
for select to anon, authenticated
using (
  status = 'published'
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at >= now())
);

drop policy if exists campaigns_manager_write on public.campaigns;
create policy campaigns_manager_write on public.campaigns
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]));

drop policy if exists campaign_products_public_select on public.campaign_products;
create policy campaign_products_public_select on public.campaign_products
for select to anon, authenticated
using (
  is_active
  and exists (
    select 1 from public.campaigns c
    where c.id = campaign_id
      and c.status = 'published'
      and (c.starts_at is null or c.starts_at <= now())
      and (c.ends_at is null or c.ends_at >= now())
  )
);

drop policy if exists campaign_products_manager_write on public.campaign_products;
create policy campaign_products_manager_write on public.campaign_products
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner','admin','producer']::text[]));

-- Pedidos públicos só devem ser criados por Edge Function com service role.
-- O cliente não recebe INSERT/UPDATE direto para impedir fraude de estoque e preço.
drop policy if exists orders_member_select on public.orders;
create policy orders_member_select on public.orders
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists orders_finance_update on public.orders;
create policy orders_finance_update on public.orders
for update to authenticated
using (public.can_manage_finance(tenant_id))
with check (public.can_manage_finance(tenant_id));

drop policy if exists order_items_member_select on public.order_items;
create policy order_items_member_select on public.order_items
for select to authenticated
using (public.is_tenant_member(tenant_id));

-- Financeiro restrito.
drop policy if exists payments_finance_select on public.payment_transactions;
create policy payments_finance_select on public.payment_transactions
for select to authenticated
using (public.can_manage_finance(tenant_id));

drop policy if exists settlements_finance_all on public.settlements;
create policy settlements_finance_all on public.settlements
for all to authenticated
using (public.can_manage_finance(tenant_id))
with check (public.can_manage_finance(tenant_id));

drop policy if exists contracts_manager_select on public.group_contracts;
create policy contracts_manager_select on public.group_contracts
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists contracts_manager_write on public.group_contracts;
create policy contracts_manager_write on public.group_contracts
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner','admin','finance']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner','admin','finance']::text[]));

-- Ingressos: equipe autorizada consulta. Emissão e alteração pertencem às Functions.
drop policy if exists tickets_member_select on public.tickets;
create policy tickets_member_select on public.tickets
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists checkin_operator_select on public.checkin_logs;
create policy checkin_operator_select on public.checkin_logs
for select to authenticated
using (public.can_operate_checkin(tenant_id));

-- Logs de auditoria são somente leitura para gestão. Inserts ocorrem por trigger/Function.
drop policy if exists audit_logs_manager_select on public.audit_logs;
create policy audit_logs_manager_select on public.audit_logs
for select to authenticated
using (public.can_manage_tenant(tenant_id));

-- Privilégios de tabela são necessários para as policies serem avaliadas.
-- O isolamento real continua sendo aplicado pelo RLS acima.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on public.campaigns to anon;
grant select on public.campaign_products to anon;
