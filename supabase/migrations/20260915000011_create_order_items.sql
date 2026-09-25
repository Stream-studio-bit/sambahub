create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  campaign_product_id uuid not null references public.campaign_products(id) on delete restrict,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  total_price numeric(12,2) not null check (total_price >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index order_items_order_idx on public.order_items (order_id);
create index order_items_tenant_idx on public.order_items (tenant_id);
create trigger order_items_set_updated_at before update on public.order_items
for each row execute function public.set_updated_at();
