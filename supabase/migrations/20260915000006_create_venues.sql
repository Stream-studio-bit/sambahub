create table public.venues (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null,
  slug text not null,
  description text,
  document text,
  email text,
  phone text,
  address_line text not null,
  address_number text not null,
  address_complement text,
  neighborhood text not null,
  city text not null,
  state text not null check (char_length(state) = 2),
  postal_code text not null,
  latitude numeric(10,7),
  longitude numeric(10,7),
  capacity integer check (capacity is null or capacity >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (tenant_id, slug)
);

create index venues_tenant_active_idx on public.venues (tenant_id, is_active);
create index venues_city_state_idx on public.venues (city, state);
create trigger venues_set_updated_at before update on public.venues
for each row execute function public.set_updated_at();
