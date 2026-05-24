-- 011_add_is_default_to_bank_accounts.sql
-- Adds default receiving account support for bank_accounts.

alter table public.bank_accounts
  add column if not exists is_default boolean not null default false;

-- Backfill: for each store, mark the newest active account as default
-- if no default account currently exists.
with stores_without_default as (
  select ba.store_id
  from public.bank_accounts ba
  where ba.is_active = true
  group by ba.store_id
  having bool_or(ba.is_default) = false
),
pick_default as (
  select distinct on (ba.store_id)
    ba.id,
    ba.store_id
  from public.bank_accounts ba
  join stores_without_default s on s.store_id = ba.store_id
  where ba.is_active = true
  order by ba.store_id, ba.created_at desc, ba.id desc
)
update public.bank_accounts ba
set is_default = true
from pick_default d
where ba.id = d.id;

create index if not exists idx_bank_accounts_store_default_active
  on public.bank_accounts(store_id, is_default, is_active);
