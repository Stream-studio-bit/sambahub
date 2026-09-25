create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  status text not null default 'draft' check (status in ('draft', 'published', 'paused', 'finished')),
  cover_image_path text,
  published_at timestamptz,
  starts_at timestamptz,
  ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index campaigns_tenant_status_idx on public.campaigns (tenant_id, status);
create index campaigns_event_status_idx on public.campaigns (event_id, status);
create trigger campaigns_set_updated_at before update on public.campaigns
for each row execute function public.set_updated_at();
