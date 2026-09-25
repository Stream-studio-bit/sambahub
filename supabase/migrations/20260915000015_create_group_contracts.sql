create table public.group_contracts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  group_id uuid not null references public.groups(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft', 'signed', 'paid', 'cancelled')),
  cache_amount numeric(12,2) not null check (cache_amount >= 0),
  currency char(3) not null default 'BRL',
  terms text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  signed_at timestamptz,
  paid_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create index group_contracts_tenant_status_idx on public.group_contracts (tenant_id, status);
create index group_contracts_group_event_idx on public.group_contracts (group_id, event_id);
create trigger group_contracts_set_updated_at before update on public.group_contracts
for each row execute function public.set_updated_at();
