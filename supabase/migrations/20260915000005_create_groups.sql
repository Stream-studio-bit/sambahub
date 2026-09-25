create table public.groups (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null,
  slug text not null,
  description text,
  contact_name text,
  contact_email text,
  contact_phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (tenant_id, slug)
);

create index groups_tenant_active_idx on public.groups (tenant_id, is_active);
create trigger groups_set_updated_at before update on public.groups
for each row execute function public.set_updated_at();
