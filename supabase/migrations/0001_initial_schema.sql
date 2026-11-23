-- FreelanceOS initial schema
-- Apply in Supabase SQL Editor. All business records belong to a workspace.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'My Workspace',
  owner_id uuid not null references auth.users(id) on delete restrict,
  storage_mode text not null default 'cloud' check (storage_mode in ('cloud','local')),
  country_code char(2) not null default 'IN',
  currency_code char(3) not null default 'INR',
  timezone text not null default 'Asia/Kolkata',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','admin','member','viewer')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create or replace function public.is_workspace_member(target_workspace uuid)
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id = target_workspace and wm.user_id = auth.uid()
  );
$$;

create or replace function public.add_workspace_owner()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.workspace_members(workspace_id,user_id,role)
  values (new.id,new.owner_id,'owner')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists workspace_owner_membership on public.workspaces;
create trigger workspace_owner_membership after insert on public.workspaces
for each row execute function public.add_workspace_owner();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare
  new_workspace uuid;
  full_name text;
begin
  full_name := coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email,'@',1));
  insert into public.profiles(id,display_name) values(new.id,full_name)
  on conflict (id) do nothing;
  insert into public.workspaces(name,owner_id)
  values(coalesce(nullif(full_name,'' ) || '''s Workspace','My Workspace'),new.id)
  returning id into new_workspace;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_freelanceos on auth.users;
create trigger on_auth_user_created_freelanceos after insert on auth.users
for each row execute function public.handle_new_user();

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  company text,
  email text,
  phone text,
  website text,
  billing_address jsonb not null default '{}'::jsonb,
  tax_id text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  name text not null,
  description text,
  status text not null default 'planning' check (status in ('planning','active','on_hold','completed','cancelled')),
  pricing_model text not null default 'fixed' check (pricing_model in ('hourly','daily','fixed','milestone','retainer')),
  currency_code char(3) not null default 'INR',
  budget numeric(14,2) not null default 0 check (budget >= 0),
  start_date date,
  due_date date,
  progress smallint not null default 0 check (progress between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.opportunities (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  title text not null,
  company text,
  source text,
  url text,
  description text,
  status text not null default 'saved' check (status in ('saved','applied','interview','negotiation','won','lost','archived')),
  pricing_model text check (pricing_model in ('hourly','daily','fixed','milestone','retainer')),
  currency_code char(3),
  estimated_value numeric(14,2) check (estimated_value is null or estimated_value >= 0),
  deadline date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  project_id uuid references public.projects(id) on delete set null,
  quote_number text not null,
  title text not null,
  status text not null default 'draft' check (status in ('draft','sent','viewed','accepted','declined','expired')),
  currency_code char(3) not null default 'INR',
  issue_date date not null default current_date,
  valid_until date,
  subtotal numeric(14,2) not null default 0,
  discount_total numeric(14,2) not null default 0,
  tax_total numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  tax_snapshot jsonb not null default '{}'::jsonb,
  document_content jsonb not null default '{}'::jsonb,
  notes text,
  terms text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,quote_number)
);

create table if not exists public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  description text not null,
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  unit text not null default 'unit',
  unit_price numeric(14,2) not null default 0 check (unit_price >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax_rate numeric(7,4) not null default 0 check (tax_rate >= 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  project_id uuid references public.projects(id) on delete set null,
  quote_id uuid references public.quotes(id) on delete set null,
  invoice_number text not null,
  title text not null,
  status text not null default 'draft' check (status in ('draft','sent','partially_paid','paid','overdue','void')),
  currency_code char(3) not null default 'INR',
  issue_date date not null default current_date,
  due_date date,
  subtotal numeric(14,2) not null default 0,
  discount_total numeric(14,2) not null default 0,
  tax_total numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  amount_paid numeric(14,2) not null default 0 check (amount_paid >= 0),
  tax_snapshot jsonb not null default '{}'::jsonb,
  document_content jsonb not null default '{}'::jsonb,
  notes text,
  terms text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,invoice_number)
);

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  description text not null,
  quantity numeric(12,3) not null default 1 check (quantity > 0),
  unit text not null default 'unit',
  unit_price numeric(14,2) not null default 0 check (unit_price >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax_rate numeric(7,4) not null default 0 check (tax_rate >= 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  description text not null,
  category text not null default 'general',
  amount numeric(14,2) not null check (amount >= 0),
  currency_code char(3) not null default 'INR',
  expense_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  amount numeric(14,2) not null check (amount > 0),
  currency_code char(3) not null default 'INR',
  payment_date date not null default current_date,
  method text,
  reference text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.workspace_settings (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  business_name text,
  business_email text,
  business_phone text,
  business_address jsonb not null default '{}'::jsonb,
  tax_registration_id text,
  country_code char(2) not null default 'IN',
  currency_code char(3) not null default 'INR',
  locale text not null default 'en-IN',
  timezone text not null default 'Asia/Kolkata',
  tax_preferences jsonb not null default '{"system":"GST","enabled":false,"inclusive":false}'::jsonb,
  document_preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists clients_workspace_idx on public.clients(workspace_id);
create index if not exists projects_workspace_idx on public.projects(workspace_id);
create index if not exists opportunities_workspace_idx on public.opportunities(workspace_id);
create index if not exists quotes_workspace_idx on public.quotes(workspace_id);
create index if not exists invoices_workspace_idx on public.invoices(workspace_id);
create index if not exists expenses_workspace_date_idx on public.expenses(workspace_id,expense_date);
create index if not exists payments_workspace_date_idx on public.payments(workspace_id,payment_date);
create index if not exists quote_items_quote_idx on public.quote_items(quote_id);
create index if not exists invoice_items_invoice_idx on public.invoice_items(invoice_id);

alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.clients enable row level security;
alter table public.projects enable row level security;
alter table public.opportunities enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_items enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.expenses enable row level security;
alter table public.payments enable row level security;
alter table public.workspace_settings enable row level security;

drop policy if exists "profile read self" on public.profiles;
create policy "profile read self" on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists "profile update self" on public.profiles;
create policy "profile update self" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "workspace members read workspace" on public.workspaces;
create policy "workspace members read workspace" on public.workspaces for select to authenticated using (public.is_workspace_member(id));
drop policy if exists "workspace owners update" on public.workspaces;
create policy "workspace owners update" on public.workspaces for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "workspace owner create" on public.workspaces;
create policy "workspace owner create" on public.workspaces for insert to authenticated with check (owner_id = auth.uid());

drop policy if exists "members read membership" on public.workspace_members;
create policy "members read membership" on public.workspace_members for select to authenticated using (public.is_workspace_member(workspace_id));

do $$
declare t text;
begin
  foreach t in array array['clients','projects','opportunities','quotes','invoices','expenses','payments','workspace_settings'] loop
    execute format('drop policy if exists "workspace members manage %I" on public.%I',t,t);
    execute format('create policy "workspace members manage %I" on public.%I for all to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id))',t,t);
  end loop;
end $$;

drop policy if exists "quote items through quote workspace" on public.quote_items;
create policy "quote items through quote workspace" on public.quote_items for all to authenticated
using (exists(select 1 from public.quotes q where q.id = quote_id and public.is_workspace_member(q.workspace_id)))
with check (exists(select 1 from public.quotes q where q.id = quote_id and public.is_workspace_member(q.workspace_id)));

drop policy if exists "invoice items through invoice workspace" on public.invoice_items;
create policy "invoice items through invoice workspace" on public.invoice_items for all to authenticated
using (exists(select 1 from public.invoices i where i.id = invoice_id and public.is_workspace_member(i.workspace_id)))
with check (exists(select 1 from public.invoices i where i.id = invoice_id and public.is_workspace_member(i.workspace_id)));

grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update on public.workspaces to authenticated;
grant select on public.workspace_members to authenticated;
grant select, insert, update, delete on public.clients, public.projects, public.opportunities, public.quotes, public.quote_items, public.invoices, public.invoice_items, public.expenses, public.payments, public.workspace_settings to authenticated;
