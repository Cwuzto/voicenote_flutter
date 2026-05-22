begin;

alter table public.orders
add column if not exists paid_by_user_id uuid references public.users(id);

create index if not exists idx_orders_paid_by_user_id
on public.orders(paid_by_user_id);

commit;
