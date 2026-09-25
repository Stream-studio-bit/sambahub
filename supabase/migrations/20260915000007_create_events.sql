create table public.events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  group_id uuid references public.groups(id) on delete set null,
  venue_id uuid not null references public.venues(id) on delete restrict,
  name text not null,
  slug text not null,
  description text,
  cover_image_path text,
  status text not null default 'draft' check (status in ('draft', 'published', 'cancelled', 'finished')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  capacity integer check (capacity is null or capacity >= 0),
  published_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (tenant_id, slug)
);

create index events_tenant_status_idx on public.events (tenant_id, status);
create index events_tenant_starts_idx on public.events (tenant_id, starts_at);
create trigger events_set_updated_at before update on public.events
for each row execute function public.set_updated_at();
