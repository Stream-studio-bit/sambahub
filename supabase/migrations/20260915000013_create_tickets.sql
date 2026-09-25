create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  campaign_product_id uuid not null references public.campaign_products(id) on delete restrict,
  code text not null unique,
  holder_name text not null,
  holder_email text not null,
  status text not null default 'issued' check (status in ('issued', 'used', 'cancelled', 'refunded')),
  issued_at timestamptz not null default timezone('utc', now()),
  used_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index tickets_event_status_idx on public.tickets (event_id, status);
create index tickets_order_idx on public.tickets (order_id);
create trigger tickets_set_updated_at before update on public.tickets
for each row execute function public.set_updated_at();
