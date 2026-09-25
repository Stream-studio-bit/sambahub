create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  document text,
  slug text not null unique,
  email text,
  phone text,
  status text not null default 'active' check (status in ('active', 'suspended', 'archived')),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create unique index tenants_document_unique on public.tenants (document) where document is not null;
create index tenants_status_idx on public.tenants (status);
create trigger tenants_set_updated_at before update on public.tenants
for each row execute function public.set_updated_at();
