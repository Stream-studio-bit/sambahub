create table public.checkin_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  checked_by_user_id uuid references public.profiles(id) on delete set null,
  ticket_code text not null,
  result text not null check (result in ('accepted', 'rejected')),
  reason text,
  checked_in_at timestamptz not null default timezone('utc', now()),
  ip_address inet,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index checkin_logs_event_created_idx on public.checkin_logs (event_id, created_at);
create index checkin_logs_ticket_created_idx on public.checkin_logs (ticket_id, created_at);
create index checkin_logs_result_created_idx on public.checkin_logs (result, created_at);
