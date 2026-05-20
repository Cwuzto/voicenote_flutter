-- 002_rls.sql
-- Apply RLS policies (OWNER full on own store, EMPLOYEE read products + create/update orders)

begin;

create or replace function public.is_store_owner(target_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.stores s
    where s.id = target_store_id and s.owner_id = auth.uid()
  );
$$;

create or replace function public.is_store_employee(target_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees e
    where e.store_id = target_store_id and e.user_id = auth.uid() and e.is_active = true
  );
$$;

create or replace function public.can_access_store(target_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_store_owner(target_store_id) or public.is_store_employee(target_store_id);
$$;

alter table public.users enable row level security;
alter table public.stores enable row level security;
alter table public.employees enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.speaker_templates enable row level security;

do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname from pg_policies
  where schemaname='public' and tablename in
  ('users','stores','employees','products','orders','order_items','bank_accounts','speaker_templates')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

create policy users_select_scope on public.users for select using (
  id = auth.uid()
  or exists (
    select 1 from public.stores s where s.owner_id = auth.uid()
      and (s.owner_id = users.id or exists (select 1 from public.employees e where e.store_id = s.id and e.user_id = users.id))
  )
  or exists (
    select 1 from public.employees me where me.user_id = auth.uid() and me.is_active = true
      and exists (
        select 1 from public.stores s2 where s2.id = me.store_id
          and (s2.owner_id = users.id or exists (select 1 from public.employees e2 where e2.store_id = s2.id and e2.user_id = users.id))
      )
  )
);
create policy users_insert_self on public.users for insert with check (id = auth.uid());
create policy users_update_self_or_owner_manage on public.users for update
using (
  id = auth.uid()
  or exists (
    select 1 from public.employees e join public.stores s on s.id = e.store_id
    where e.user_id = users.id and s.owner_id = auth.uid()
  )
)
with check (
  id = auth.uid()
  or exists (
    select 1 from public.employees e join public.stores s on s.id = e.store_id
    where e.user_id = users.id and s.owner_id = auth.uid()
  )
);

create policy stores_select on public.stores for select using (public.can_access_store(id));
create policy stores_insert on public.stores for insert with check (owner_id = auth.uid());
create policy stores_update on public.stores for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy stores_delete on public.stores for delete using (owner_id = auth.uid());

create policy employees_select on public.employees for select using (public.can_access_store(store_id));
create policy employees_insert_owner on public.employees for insert with check (public.is_store_owner(store_id));
create policy employees_update_owner on public.employees for update using (public.is_store_owner(store_id)) with check (public.is_store_owner(store_id));
create policy employees_delete_owner on public.employees for delete using (public.is_store_owner(store_id));

create policy products_select on public.products for select using (public.can_access_store(store_id));
create policy products_insert_owner on public.products for insert with check (public.is_store_owner(store_id));
create policy products_update_owner on public.products for update using (public.is_store_owner(store_id)) with check (public.is_store_owner(store_id));
create policy products_delete_owner on public.products for delete using (public.is_store_owner(store_id));

create policy orders_select on public.orders for select using (public.can_access_store(store_id));
create policy orders_insert on public.orders for insert with check (public.can_access_store(store_id) and seller_id = auth.uid());
create policy orders_update on public.orders for update using (public.can_access_store(store_id)) with check (public.can_access_store(store_id));
create policy orders_delete_owner on public.orders for delete using (public.is_store_owner(store_id));

create policy order_items_select on public.order_items for select using (
  exists (select 1 from public.orders o where o.id = order_items.order_id and public.can_access_store(o.store_id))
);
create policy order_items_insert on public.order_items for insert with check (
  exists (select 1 from public.orders o where o.id = order_items.order_id and public.can_access_store(o.store_id))
);
create policy order_items_update on public.order_items for update using (
  exists (select 1 from public.orders o where o.id = order_items.order_id and public.can_access_store(o.store_id))
) with check (
  exists (select 1 from public.orders o where o.id = order_items.order_id and public.can_access_store(o.store_id))
);
create policy order_items_delete on public.order_items for delete using (
  exists (select 1 from public.orders o where o.id = order_items.order_id and public.can_access_store(o.store_id))
);

create policy bank_accounts_select on public.bank_accounts for select using (public.can_access_store(store_id));
create policy bank_accounts_insert_owner on public.bank_accounts for insert with check (public.is_store_owner(store_id));
create policy bank_accounts_update_owner on public.bank_accounts for update using (public.is_store_owner(store_id)) with check (public.is_store_owner(store_id));
create policy bank_accounts_delete_owner on public.bank_accounts for delete using (public.is_store_owner(store_id));

create policy speaker_templates_select on public.speaker_templates for select using (public.can_access_store(store_id));
create policy speaker_templates_insert_owner on public.speaker_templates for insert with check (public.is_store_owner(store_id));
create policy speaker_templates_update_owner on public.speaker_templates for update using (public.is_store_owner(store_id)) with check (public.is_store_owner(store_id));
create policy speaker_templates_delete_owner on public.speaker_templates for delete using (public.is_store_owner(store_id));

commit;
