create table public.campaign_products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  campaign_id uuid not null references public.campaigns(id) on delete restrict,
  name text not null,
  description text,
  type text not null check (type in ('ticket', 'combo', 'table', 'vip', 'courtesy')),
  price numeric(12,2) not null check (price >= 0),
  stock_quantity integer check (stock_quantity is null or stock_quantity >= 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (campaign_id, name)
);

create index campaign_products_tenant_active_idx on public.campaign_products (tenant_id, is_active);
create index campaign_products_campaign_sort_idx on public.campaign_products (campaign_id, sort_order);
create trigger campaign_products_set_updated_at before update on public.campaign_products
for each row execute function public.set_updated_at();
