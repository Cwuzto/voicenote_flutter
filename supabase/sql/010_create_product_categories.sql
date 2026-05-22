begin;

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, name)
);

create index if not exists idx_product_categories_store_name
on public.product_categories (store_id, name);

insert into public.product_categories (store_id, name)
select s.id, v.name
from public.stores s
cross join (values ('Món chính'), ('Món phụ'), ('Đồ uống'), ('Khác')) as v(name)
on conflict (store_id, name) do nothing;

commit;
