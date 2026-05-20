-- 003_seed_demo.sql
-- Seed demo data with robust owner resolution.
-- Option A: set v_target_username below.
-- Option B: leave blank '' to auto-pick latest user from auth.users.

do $$
declare
  v_target_username text := ''; -- ex: 'chuquan01'
  v_owner_id uuid;
  v_owner_username text;
  v_owner_email text;
  v_store_id uuid;
  v_order_id_1 uuid;
  v_order_id_2 uuid;
begin
  if coalesce(trim(v_target_username), '') <> '' then
    select id, username
      into v_owner_id, v_owner_username
    from public.users
    where username = trim(v_target_username)
    limit 1;
  end if;

  if v_owner_id is null then
    -- fallback: latest signed up auth user
    select au.id, au.email
      into v_owner_id, v_owner_email
    from auth.users au
    order by au.created_at desc
    limit 1;

    if v_owner_id is null then
      raise exception 'No user found in auth.users. Please register/login first.';
    end if;

    v_owner_username := split_part(coalesce(v_owner_email, 'owner_demo@voicepos.local'), '@', 1);

    insert into public.users(id, full_name, username, role, is_active)
    values (v_owner_id, 'Owner Demo', v_owner_username, 'OWNER', true)
    on conflict (id) do update
      set username = excluded.username,
          role = 'OWNER',
          is_active = true;
  end if;

  insert into public.stores(owner_id, name, phone, address)
  values (v_owner_id, 'VoicePOS Demo Store', '0909123456', '123 Demo Street')
  on conflict do nothing;

  select id into v_store_id
  from public.stores
  where owner_id = v_owner_id
  order by created_at desc
  limit 1;

  if v_store_id is null then
    raise exception 'Could not resolve store for owner_id=%', v_owner_id;
  end if;

  insert into public.products(store_id, name, price, is_active)
  values
    (v_store_id, 'Pho bo', 45000, true),
    (v_store_id, 'Bun cha', 50000, true),
    (v_store_id, 'Ca phe sua', 25000, true),
    (v_store_id, 'Tra dao', 30000, true)
  on conflict do nothing;

  insert into public.bank_accounts(store_id, bank_name, account_number, account_holder, is_active)
  values (v_store_id, 'VCB', '0123456789', 'VoicePOS Demo', true)
  on conflict do nothing;

  insert into public.speaker_templates(store_id, title, content, is_default)
  values (v_store_id, 'Mac dinh', 'Da nhan {so_tien}. Cam on quy khach!', true)
  on conflict do nothing;

  insert into public.orders(store_id, seller_id, customer_name, status, payment_method, total_amount)
  values (v_store_id, v_owner_id, 'Khach le', 'UNPAID', 'CASH', 95000)
  returning id into v_order_id_1;

  insert into public.order_items(order_id, product_name, quantity, unit_price, note)
  values
    (v_order_id_1, 'Pho bo', 1, 45000, null),
    (v_order_id_1, 'Bun cha', 1, 50000, 'It da');

  insert into public.orders(store_id, seller_id, customer_name, status, payment_method, total_amount)
  values (v_store_id, v_owner_id, 'Ban so 5', 'PAID', 'CASH', 75000)
  returning id into v_order_id_2;

  insert into public.order_items(order_id, product_name, quantity, unit_price, note)
  values
    (v_order_id_2, 'Ca phe sua', 1, 25000, null),
    (v_order_id_2, 'Tra dao', 1, 30000, null),
    (v_order_id_2, 'Pho bo', 1, 20000, 'Khuyen mai');

  raise notice 'Seed completed. owner_id=%, username=%', v_owner_id, v_owner_username;
end $$;
