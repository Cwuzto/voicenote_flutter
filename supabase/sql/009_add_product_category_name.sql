begin;

alter table public.products
add column if not exists category_name text not null default 'Khác';

create index if not exists idx_products_store_category
on public.products (store_id, category_name);

commit;
