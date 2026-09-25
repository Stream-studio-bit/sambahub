create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  venue_id uuid not null references public.venues(id) on delete restrict,
  reference text not null unique,
  status text not null default 'pending' check (status in ('pending', 'scheduled', 'paid', 'failed', 'cancelled')),
  gross_amount numeric(12,2) not null check (gross_amount >= 0),
  platform_fee numeric(12,2) not null default 0 check (platform_fee >= 0),
  payment_fee numeric(12,2) not null default 0 check (payment_fee >= 0),
  venue_amount numeric(12,2) not null default 0 check (venue_amount >= 0),
  group_cache_amount numeric(12,2) not null default 0 check (group_cache_amount >= 0),
  net_amount numeric(12,2) not null default 0,
  scheduled_at timestamptz,
  paid_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (tenant_id, order_id)
);

create index settlements_tenant_status_idx on public.settlements (tenant_id, status);
create index settlements_venue_status_idx on public.settlements (venue_id, status);
create trigger settlements_set_updated_at before update on public.settlements
for each row execute function public.set_updated_at();
