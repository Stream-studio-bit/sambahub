create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  order_id uuid not null unique references public.orders(id) on delete restrict,
  provider text not null default 'mercadopago',
  provider_transaction_id text,
  idempotency_key text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'refunded', 'cancelled')),
  amount numeric(12,2) not null check (amount >= 0),
  payment_fee numeric(12,2) not null default 0 check (payment_fee >= 0),
  provider_status text,
  provider_payload jsonb,
  paid_at timestamptz,
  refunded_at timestamptz,
  last_webhook_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (provider, provider_transaction_id),
  unique (tenant_id, idempotency_key)
);

create index payment_transactions_status_idx on public.payment_transactions (tenant_id, status);
create index payment_transactions_webhook_idx on public.payment_transactions (last_webhook_at);
create trigger payment_transactions_set_updated_at before update on public.payment_transactions
for each row execute function public.set_updated_at();
