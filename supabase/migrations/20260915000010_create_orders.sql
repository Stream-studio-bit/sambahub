create table public.orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  campaign_id uuid not null references public.campaigns(id) on delete restrict,
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'cancelled', 'refunded', 'failed')),
  idempotency_key text not null,
  gross_amount numeric(12,2) not null default 0 check (gross_amount >= 0),
  platform_fee numeric(12,2) not null default 0 check (platform_fee >= 0),
  payment_fee numeric(12,2) not null default 0 check (payment_fee >= 0),
  net_amount numeric(12,2) not null default 0,
  paid_at timestamptz,
  cancelled_at timestamptz,
  refunded_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (tenant_id, idempotency_key)
);

create index orders_tenant_status_idx on public.orders (tenant_id, status);
create index orders_campaign_status_idx on public.orders (campaign_id, status);
create index orders_customer_email_idx on public.orders (customer_email);
create trigger orders_set_updated_at before update on public.orders
for each row execute function public.set_updated_at();
