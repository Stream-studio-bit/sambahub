-- Catálogo base do tenant.
-- Produtos de campanhas continuam em campaign_products; estas tabelas representam
-- o catálogo reutilizável para composição de campanhas e cardápios.

create table public.catalog_categories (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null check (length(btrim(name)) between 1 and 120),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (tenant_id, id),
  unique (tenant_id, slug)
);

create index catalog_categories_tenant_active_order_idx
  on public.catalog_categories (tenant_id, is_active, sort_order)
  where deleted_at is null;

create trigger catalog_categories_set_updated_at
before update on public.catalog_categories
for each row execute function public.set_updated_at();

create table public.catalog_products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  category_id uuid not null,
  name text not null check (length(btrim(name)) between 1 and 160),
  description text,
  price numeric(12,2) not null check (price >= 0),
  stock_quantity integer check (stock_quantity is null or stock_quantity >= 0),
  image_path text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (category_id, id),
  unique (category_id, name),
  constraint catalog_products_category_tenant_fk
    foreign key (tenant_id, category_id)
    references public.catalog_categories (tenant_id, id)
    on delete restrict
);

create index catalog_products_tenant_active_idx
  on public.catalog_products (tenant_id, is_active)
  where deleted_at is null;

create index catalog_products_category_sort_idx
  on public.catalog_products (category_id, sort_order)
  where deleted_at is null;

create trigger catalog_products_set_updated_at
before update on public.catalog_products
for each row execute function public.set_updated_at();

alter table public.catalog_categories enable row level security;
alter table public.catalog_products enable row level security;

-- Leitura do catálogo somente por membros do tenant.
drop policy if exists catalog_categories_member_select on public.catalog_categories;
create policy catalog_categories_member_select
on public.catalog_categories
for select to authenticated
using (public.is_tenant_member(tenant_id));

-- Escrita reservada às funções que administram o catálogo.
drop policy if exists catalog_categories_manager_write on public.catalog_categories;
create policy catalog_categories_manager_write
on public.catalog_categories
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner', 'admin', 'producer']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner', 'admin', 'producer']::text[]));

drop policy if exists catalog_products_member_select on public.catalog_products;
create policy catalog_products_member_select
on public.catalog_products
for select to authenticated
using (public.is_tenant_member(tenant_id));

drop policy if exists catalog_products_manager_write on public.catalog_products;
create policy catalog_products_manager_write
on public.catalog_products
for all to authenticated
using (public.has_tenant_role(tenant_id, array['owner', 'admin', 'producer']::text[]))
with check (public.has_tenant_role(tenant_id, array['owner', 'admin', 'producer']::text[]));

-- A API pública não acessa o catálogo administrativo diretamente. Produtos
-- expostos ao público devem ser publicados em campaign_products, que possui
-- suas próprias políticas de campanha publicada.
revoke all on public.catalog_categories from anon;
revoke all on public.catalog_products from anon;
grant select, insert, update, delete on public.catalog_categories to authenticated;
grant select, insert, update, delete on public.catalog_products to authenticated;
