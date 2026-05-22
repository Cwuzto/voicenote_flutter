-- 001_schema.sql
-- Create VoicePOS schema tables/indexes/triggers

begin;

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key,
  full_name text not null,
  username text unique,
  role text not null check (role in ('OWNER','EMPLOYEE')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id),
  name text not null,
  phone text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  user_id uuid not null references public.users(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (store_id, user_id)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  name text not null,
  category_name text not null default 'Khác',
  price bigint not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, name)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  seller_id uuid not null references public.users(id),
  paid_by_user_id uuid references public.users(id),
  customer_name text,
  status text not null default 'UNPAID' check (status in ('UNPAID','PAID')),
  payment_method text not null default 'CASH',
  total_amount bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id),
  product_name text not null,
  quantity integer not null default 1,
  unit_price bigint not null default 0,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  bank_name text not null,
  account_number text not null,
  account_holder text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.speaker_templates (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  title text not null,
  content text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_products_store_active on public.products(store_id, is_active);
create index if not exists idx_product_categories_store_name on public.product_categories(store_id, name);
create index if not exists idx_orders_store_created on public.orders(store_id, created_at desc);
create index if not exists idx_orders_store_status_created on public.orders(store_id, status, created_at desc);
create index if not exists idx_order_items_order_id on public.order_items(order_id);
create index if not exists idx_employees_store_user on public.employees(store_id, user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists trg_stores_updated_at on public.stores;
create trigger trg_stores_updated_at before update on public.stores
for each row execute function public.set_updated_at();

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at before update on public.products
for each row execute function public.set_updated_at();

drop trigger if exists trg_product_categories_updated_at on public.product_categories;
create trigger trg_product_categories_updated_at before update on public.product_categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at before update on public.orders
for each row execute function public.set_updated_at();

drop trigger if exists trg_speaker_templates_updated_at on public.speaker_templates;
create trigger trg_speaker_templates_updated_at before update on public.speaker_templates
for each row execute function public.set_updated_at();

commit;
