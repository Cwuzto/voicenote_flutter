-- 003_seed_demo.sql
-- Reset demo data for the current store and seed fake data
-- from 2025-01-10 to current_date.
--
-- Run after:
-- 1. 001_schema.sql
-- 2. 002_rls.sql
-- 3. 004_drop_username_use_email.sql
-- 4. 005_add_paid_by_user_to_orders.sql
-- IMPORTANT:
-- Set v_target_email or v_target_username below to the SAME account
-- you are currently using to log into the app.

begin;

alter table public.users
add column if not exists email text;

alter table public.orders
add column if not exists paid_by_user_id uuid references public.users(id);

do $$
declare
  v_target_username text := '';
  v_target_email text := 'YOUR_LOGIN_EMAIL_HERE';

  v_owner_id uuid;
  v_owner_username text;
  v_owner_email text;
  v_store_id uuid;

  v_day date;
  v_created_at timestamptz;
  v_order_id uuid;
  v_total_amount bigint;
  v_orders_for_day integer;
  v_line_count integer;
  v_product_index integer;
  v_line_index integer;
  v_quantity integer;
  v_seller_index integer;
  v_paid_by_index integer;
  v_customer_index integer;
  v_note_index integer;
  v_is_paid boolean;

  v_employee_1_id uuid := '11111111-1111-4111-8111-111111111111';
  v_employee_2_id uuid := '22222222-2222-4222-8222-222222222222';
  v_employee_3_id uuid := '33333333-3333-4333-8333-333333333333';

  v_staff_ids uuid[];
  v_product_names text[];
  v_product_prices bigint[];
  v_customer_names text[];
  v_notes text[];

  v_paid_orders integer := 0;
  v_unpaid_orders integer := 0;
  v_total_orders integer := 0;
begin
  if coalesce(trim(v_target_username), '') = ''
     and coalesce(trim(v_target_email), '') in ('', 'YOUR_LOGIN_EMAIL_HERE') then
    raise exception
      'Please set v_target_email or v_target_username at the top of 003_seed_demo.sql before running.';
  end if;

  if coalesce(trim(v_target_username), '') <> '' then
    select id, username, email
      into v_owner_id, v_owner_username, v_owner_email
    from public.users
    where username = trim(v_target_username)
    limit 1;
  end if;

  if v_owner_id is null and coalesce(trim(v_target_email), '') <> '' then
    select id, username, email
      into v_owner_id, v_owner_username, v_owner_email
    from public.users
    where lower(email) = lower(trim(v_target_email))
    limit 1;
  end if;

  if v_owner_id is null then
    select au.id, au.email
      into v_owner_id, v_owner_email
    from auth.users au
    order by au.created_at desc
    limit 1;

    if v_owner_id is null then
      raise exception 'No user found in auth.users. Please register/login first.';
    end if;

    v_owner_username := split_part(
      coalesce(v_owner_email, 'owner_demo@voicepos.local'),
      '@',
      1
    );
  end if;

  insert into public.users(id, full_name, username, email, role, is_active)
  values (
    v_owner_id,
    'Chủ cửa hàng demo',
    coalesce(nullif(trim(v_owner_username), ''), 'owner_demo'),
    coalesce(nullif(trim(v_owner_email), ''), 'owner_demo@voicepos.local'),
    'OWNER',
    true
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        username = excluded.username,
        email = excluded.email,
        role = 'OWNER',
        is_active = true;

  select id
    into v_store_id
  from public.stores
  where owner_id = v_owner_id
  order by created_at desc
  limit 1;

  if v_store_id is null then
    insert into public.stores(owner_id, name, phone, address)
    values (
      v_owner_id,
      'VoiceNote Demo Store',
      '0909123456',
      '123 Đường Demo, Quận 1, TP.HCM'
    )
    returning id into v_store_id;
  end if;

  update public.stores
  set name = 'VoiceNote Demo Store',
      phone = '0909123456',
      address = '123 Đường Demo, Quận 1, TP.HCM'
  where id = v_store_id;

  delete from public.order_items
  where order_id in (
    select id from public.orders where store_id = v_store_id
  );

  delete from public.orders
  where store_id = v_store_id;

  delete from public.employees
  where store_id = v_store_id;

  delete from public.products
  where store_id = v_store_id;

  delete from public.bank_accounts
  where store_id = v_store_id;

  delete from public.speaker_templates
  where store_id = v_store_id;

  insert into public.users(id, full_name, username, email, role, is_active)
  values
    (
      v_employee_1_id,
      'Nguyễn Minh Anh',
      'demo_emp_01',
      'demo_emp_01@voicenote.local',
      'EMPLOYEE',
      true
    ),
    (
      v_employee_2_id,
      'Trần Hoàng Phúc',
      'demo_emp_02',
      'demo_emp_02@voicenote.local',
      'EMPLOYEE',
      true
    ),
    (
      v_employee_3_id,
      'Lê Thu Hà',
      'demo_emp_03',
      'demo_emp_03@voicenote.local',
      'EMPLOYEE',
      true
    )
  on conflict (id) do update
    set full_name = excluded.full_name,
        username = excluded.username,
        email = excluded.email,
        role = 'EMPLOYEE',
        is_active = true;

  insert into public.employees(store_id, user_id, is_active)
  values
    (v_store_id, v_employee_1_id, true),
    (v_store_id, v_employee_2_id, true),
    (v_store_id, v_employee_3_id, true)
  on conflict (store_id, user_id) do update
    set is_active = true;

  v_product_names := array[
    'Phở bò',
    'Bún chả',
    'Cơm gà',
    'Bánh mì',
    'Mì xào bò',
    'Gỏi cuốn',
    'Trà đào',
    'Cà phê sữa',
    'Cà phê đen',
    'Bạc xỉu',
    'Nước cam',
    'Sinh tố bơ',
    'Kim chi',
    'Há cảo',
    'Khoai tây chiên',
    'Trà sữa'
  ];

  v_product_prices := array[
    45000,
    52000,
    55000,
    22000,
    48000,
    35000,
    32000,
    28000,
    24000,
    30000,
    35000,
    42000,
    25000,
    39000,
    30000,
    38000
  ];

  for v_product_index in 1..array_length(v_product_names, 1) loop
    insert into public.products(store_id, name, price, is_active)
    values (
      v_store_id,
      v_product_names[v_product_index],
      v_product_prices[v_product_index],
      true
    );
  end loop;

  insert into public.bank_accounts(
    store_id,
    bank_name,
    account_number,
    account_holder,
    is_default,
    is_active
  )
  values
    (v_store_id, 'Vietcombank', '0123456789', 'VOICENOTE DEMO STORE', true, true),
    (v_store_id, 'MB Bank', '0987654321', 'VOICENOTE DEMO STORE', false, true);

  insert into public.speaker_templates(store_id, title, content, is_default)
  values
    (
      v_store_id,
      'Mẫu mặc định',
      'Đã nhận {so_tien}. Cảm ơn quý khách!',
      true
    ),
    (
      v_store_id,
      'Mẫu thân thiện',
      'Tiền vào rồi ạ, em cảm ơn mình nhiều!',
      false
    ),
    (
      v_store_id,
      'Mẫu ngắn gọn',
      'Đã nhận {so_tien} đồng.',
      false
    );

  v_staff_ids := array[v_owner_id, v_employee_1_id, v_employee_2_id, v_employee_3_id];

  v_customer_names := array[
    'Khách lẻ',
    'Bàn số 1',
    'Bàn số 2',
    'Bàn số 3',
    'Bàn số 5',
    'Bàn VIP',
    'Anh Nam',
    'Chị Linh',
    'Công ty ABC',
    'Công ty Minh Phát',
    'GrabFood',
    'ShopeeFood',
    'Khách mang đi',
    'Đơn online',
    'Khách quen'
  ];

  v_notes := array[
    null,
    null,
    null,
    'Ít đá',
    'Không đá',
    'Ít đường',
    'Không hành',
    'Không ớt',
    'Thêm nước chấm',
    'Giao gấp'
  ];

  for v_day in
    select gs::date
    from generate_series(date '2025-01-10', current_date, interval '1 day') gs
  loop
    v_orders_for_day := 1 + mod(extract(doy from v_day)::int + extract(day from v_day)::int, 4);
    if extract(isodow from v_day) in (6, 7) then
      v_orders_for_day := v_orders_for_day + 1;
    end if;

    for v_seller_index in 1..v_orders_for_day loop
      v_is_paid := not (
        v_day >= current_date - 2
        and mod(v_seller_index + extract(day from v_day)::int, 4) = 0
      );
      v_customer_index := 1 + mod(
        extract(doy from v_day)::int + (v_seller_index * 3),
        array_length(v_customer_names, 1)
      );
      v_paid_by_index := 1 + mod(
        extract(day from v_day)::int + v_seller_index,
        array_length(v_staff_ids, 1)
      );

      v_created_at := (
        v_day::timestamp
        + make_interval(
            hours => 7 + mod(v_seller_index * 3 + extract(day from v_day)::int, 14),
            mins => mod(v_seller_index * 17 + extract(month from v_day)::int, 60)
          )
      );

      insert into public.orders(
        store_id,
        seller_id,
        paid_by_user_id,
        customer_name,
        status,
        payment_method,
        total_amount,
        created_at,
        updated_at
      )
      values (
        v_store_id,
        v_staff_ids[1 + mod(extract(day from v_day)::int + v_seller_index, array_length(v_staff_ids, 1))],
        case when v_is_paid then v_staff_ids[v_paid_by_index] else null end,
        v_customer_names[v_customer_index],
        case when v_is_paid then 'PAID' else 'UNPAID' end,
        case
          when mod(v_seller_index + extract(month from v_day)::int, 3) = 0 then 'BANK'
          else 'CASH'
        end,
        0,
        v_created_at,
        v_created_at
      )
      returning id into v_order_id;

      v_line_count := 1 + mod(
        extract(day from v_day)::int + v_seller_index,
        4
      );
      v_total_amount := 0;

      for v_line_index in 1..v_line_count loop
        v_product_index := 1 + mod(
          extract(doy from v_day)::int + (v_seller_index * 5) + v_line_index,
          array_length(v_product_names, 1)
        );
        v_quantity := 1 + mod(
          extract(day from v_day)::int + v_seller_index + v_line_index,
          3
        );
        v_note_index := 1 + mod(
          extract(month from v_day)::int + v_seller_index + v_line_index,
          array_length(v_notes, 1)
        );

        insert into public.order_items(
          order_id,
          product_name,
          quantity,
          unit_price,
          note,
          created_at
        )
        values (
          v_order_id,
          v_product_names[v_product_index],
          v_quantity,
          v_product_prices[v_product_index],
          v_notes[v_note_index],
          v_created_at + make_interval(mins => v_line_index)
        );

        v_total_amount := v_total_amount
          + (v_quantity * v_product_prices[v_product_index]);
      end loop;

      update public.orders
      set total_amount = v_total_amount,
          updated_at = v_created_at
      where id = v_order_id;

      v_total_orders := v_total_orders + 1;
      if v_is_paid then
        v_paid_orders := v_paid_orders + 1;
      else
        v_unpaid_orders := v_unpaid_orders + 1;
      end if;
    end loop;
  end loop;

  raise notice
    'Seed completed for store % | orders=% | paid=% | unpaid=% | from % to %',
    v_store_id,
    v_total_orders,
    v_paid_orders,
    v_unpaid_orders,
    date '2025-01-10',
    current_date;
end $$;

commit;
