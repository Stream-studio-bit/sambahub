create table public.tenant_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'producer', 'finance', 'checkin', 'group_manager', 'viewer')),
  status text not null default 'active' check (status in ('active', 'invited', 'suspended')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (tenant_id, user_id)
);

create index memberships_user_status_idx on public.tenant_memberships (user_id, status);
create index memberships_tenant_role_idx on public.tenant_memberships (tenant_id, role);
create trigger memberships_set_updated_at before update on public.tenant_memberships
for each row execute function public.set_updated_at();
