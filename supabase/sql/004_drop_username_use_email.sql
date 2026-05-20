-- 004_drop_username_use_email.sql
-- Run once after migrating app to email-only user flow

begin;

alter table public.users add column if not exists email text;

update public.users u
set email = lower(au.email)
from auth.users au
where au.id = u.id
  and (u.email is null or u.email = '');

create unique index if not exists idx_users_email_unique
on public.users (lower(email))
where email is not null;

commit;
