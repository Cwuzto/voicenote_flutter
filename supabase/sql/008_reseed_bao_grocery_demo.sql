-- 008_reseed_bao_grocery_demo.sql
-- Resets app data in public schema and seeds a restaurant food-and-drink demo
-- for the auth user bao@gmail.com without deleting auth.users.
--
-- Demo shape:
-- - 1 owner store
-- - 3 demo employees
-- - 16 products with food-and-drink pricing
-- - 3 bank accounts
-- - 4 speaker templates
-- - Orders spread from 2025-05-01 to current_date
-- - Seasonal patterns:
--   - Rainy season boosts noodles / hot drinks
--   - Back-to-school boosts affordable combo meals / drinks
--   - Tet boosts family-size dishes / beverage orders
--   - Weekend traffic is higher than weekdays
--   - Last 3 days keep a few unpaid orders for demo variety

begin;

alter table public.users
add column if not exists email text;

alter table public.orders
add column if not exists paid_by_user_id uuid references public.users(id);

create index if not exists idx_orders_paid_by_user_id
on public.orders (paid_by_user_id);

delete from public.order_items;
delete from public.orders;
delete from public.employees;
delete from public.products;
delete from public.bank_accounts;
delete from public.speaker_templates;
delete from public.stores;
delete from public.users;

do $$
declare
  v_target_email text := 'bao@gmail.com';

  v_owner_id uuid;
  v_owner_email text;
  v_store_id uuid;

  v_day date;
  v_created_at timestamptz;
  v_order_id uuid;
  v_total_amount bigint;
  v_orders_for_day integer;
  v_line_count integer;
  v_line_index integer;
  v_seller_index integer;
  v_customer_index integer;
  v_note_index integer;
  v_is_paid boolean;
  v_payment_method text;
  v_paid_by_index integer;
  v_product_pick integer;
  v_product_index integer;
  v_quantity integer;
  v_month integer;
  v_dow integer;
  v_base_seed integer;
  v_seasonality integer;

  v_emp_1 uuid := '11111111-1111-4111-8111-111111111111';
  v_emp_2 uuid := '22222222-2222-4222-8222-222222222222';
  v_emp_3 uuid := '33333333-3333-4333-8333-333333333333';

  v_staff_ids uuid[];
  v_product_names text[];
  v_product_categories text[];
  v_product_prices bigint[];
  v_customer_names text[];
  v_notes text[];
  v_product_ids uuid[];

  v_total_orders integer := 0;
  v_paid_orders integer := 0;
  v_unpaid_orders integer := 0;
begin
  select au.id, au.email
    into v_owner_id, v_owner_email
  from auth.users au
  where lower(au.email) = lower(v_target_email)
  order by au.created_at desc
  limit 1;

  if v_owner_id is null then
    raise exception 'Could not find auth user for %', v_target_email;
  end if;

  insert into public.users (
    id,
    full_name,
    username,
    role,
    is_active,
    created_at,
    updated_at,
    email
  )
  values (
    v_owner_id,
    'Bảo Demo',
    'bao_demo',
    'OWNER',
    true,
    '2025-05-01 08:00:00+00',
    current_timestamp,
    v_owner_email
  );

  insert into public.stores (
    owner_id,
    name,
    phone,
    address,
    created_at,
    updated_at
  )
  values (
    v_owner_id,
    'Quán Ăn Bảo Demo',
    '0901234567',
    '28 Nguyễn Huệ, Quận 1, TP.HCM',
    '2025-05-01 08:30:00+00',
    current_timestamp
  )
  returning id into v_store_id;

  insert into public.users (
    id,
    full_name,
    username,
    role,
    is_active,
    created_at,
    updated_at,
    email
  )
  values
    (
      v_emp_1,
      'Nguyễn Minh Anh',
      'minhanh_demo',
      'EMPLOYEE',
      true,
      '2025-05-03 08:00:00+00',
      current_timestamp,
      'demo_emp_01@voicenote.local'
    ),
    (
      v_emp_2,
      'Trần Hoàng Phúc',
      'phuc_demo',
      'EMPLOYEE',
      true,
      '2025-05-07 08:00:00+00',
      current_timestamp,
      'demo_emp_02@voicenote.local'
    ),
    (
      v_emp_3,
      'Lê Thu Hà',
      'thuha_demo',
      'EMPLOYEE',
      true,
      '2025-05-12 08:00:00+00',
      current_timestamp,
      'demo_emp_03@voicenote.local'
    );

  insert into public.employees (store_id, user_id, is_active, created_at)
  values
    (v_store_id, v_emp_1, true, '2025-05-04 08:00:00+00'),
    (v_store_id, v_emp_2, true, '2025-05-08 08:00:00+00'),
    (v_store_id, v_emp_3, true, '2025-05-13 08:00:00+00');

  v_product_names := array[
    'Cơm gà xối mỡ',
    'Bún bò Huế',
    'Phở bò tái',
    'Mì xào bò',
    'Bánh xèo',
    'Gỏi cuốn tôm thịt',
    'Chả giò',
    'Lẩu Thái hải sản',
    'Cơm tấm sườn nướng',
    'Hủ tiếu Nam Vang',
    'Trà đá',
    'Trà tắc',
    'Nước suối',
    'Coca Cola',
    'Pepsi',
    'Cam ép'
  ];

  v_product_prices := array[
    45000,
    50000,
    55000,
    48000,
    55000,
    35000,
    45000,
    249000,
    52000,
    50000,
    5000,
    12000,
    10000,
    15000,
    15000,
    25000
  ];

  v_product_categories := array[
    'Món chính',
    'Món chính',
    'Món chính',
    'Món chính',
    'Món chính',
    'Món phụ',
    'Món phụ',
    'Món chính',
    'Món chính',
    'Món chính',
    'Đồ uống',
    'Đồ uống',
    'Đồ uống',
    'Đồ uống',
    'Đồ uống',
    'Đồ uống'
  ];

  for v_product_index in 1..array_length(v_product_names, 1) loop
    insert into public.products (
      store_id,
      name,
      category_name,
      price,
      is_active,
      created_at,
      updated_at
    )
    values (
      v_store_id,
      v_product_names[v_product_index],
      v_product_categories[v_product_index],
      v_product_prices[v_product_index],
      true,
      '2025-05-01 09:00:00+00',
      current_timestamp
    );
  end loop;

  select array_agg(id order by array_position(v_product_names, name))
    into v_product_ids
  from public.products
  where store_id = v_store_id;

  insert into public.bank_accounts (
    store_id,
    bank_name,
    account_number,
    account_holder,
    is_active,
    created_at
  )
  values
    (v_store_id, 'Vietcombank', '0123456789', 'BẢO DEMO', true, '2025-05-02 08:00:00+00'),
    (v_store_id, 'Techcombank', '1900368686', 'BẢO DEMO', false, '2025-11-15 08:00:00+00'),
    (v_store_id, 'MB Bank', '6868999999', 'BẢO DEMO', true, '2026-01-05 08:00:00+00');

  insert into public.speaker_templates (
    store_id,
    title,
    content,
    is_default,
    created_at,
    updated_at
  )
  values
    (
      v_store_id,
      'Chào khách vào cửa',
      'Quán ăn Bảo xin chào, hôm nay có nhiều món mới và ưu đãi cuối ngày.',
      true,
      '2025-05-01 10:00:00+00',
      current_timestamp
    ),
    (
      v_store_id,
      'Thông báo thanh toán',
      'Quý khách vui lòng kiểm tra hóa đơn và thanh toán tại quầy thu ngân.',
      false,
      '2025-06-10 10:00:00+00',
      current_timestamp
    ),
    (
      v_store_id,
      'Thông báo chuyển khoản',
      'Đã nhận tiền chuyển khoản, Quán ăn Bảo cảm ơn quý khách.',
      false,
      '2025-12-01 10:00:00+00',
      current_timestamp
    ),
    (
      v_store_id,
      'Thông báo khuyến mãi',
      'Khuyến mãi cuối tuần đang diễn ra, mua nhiều tiết kiệm hơn.',
      false,
      '2026-03-20 10:00:00+00',
      current_timestamp
    );

  v_staff_ids := array[v_owner_id, v_emp_1, v_emp_2, v_emp_3];

  v_customer_names := array[
    'Khách lẻ',
    'Anh Nam',
    'Chị Linh',
    'Gia đình An',
    'Văn phòng tầng 3',
    'Grab giao nhanh',
    'Shipper quen',
    'Khách chung cư A1',
    'Khách công ty Minh Phát',
    'Cô Hằng',
    'Chú Tuấn',
    'Nhà trẻ Họa Mi',
    'Phòng tập gym 24h',
    'Cửa hàng hoa tươi',
    'Khách mua sỉ',
    'Khách đặt trước'
  ];

  v_notes := array[
    null,
    null,
    null,
    'Gửi thêm túi giấy',
    'Khách sẽ ghé lấy sau 17h',
    'Cần xuất hóa đơn',
    'Khách quen thanh toán sau',
    'Giao tận nơi',
    'Ưu tiên hàng mới nhập',
    'Khuyến mãi combo'
  ];

  for v_day in
    select gs::date
    from generate_series(date '2025-05-01', current_date, interval '1 day') as gs
  loop
    v_month := extract(month from v_day)::int;
    v_dow := extract(isodow from v_day)::int;
    v_base_seed := extract(doy from v_day)::int + (extract(day from v_day)::int * 3);
    v_orders_for_day := 2 + mod(v_base_seed, 3);

    if v_dow in (6, 7) then
      v_orders_for_day := v_orders_for_day + 2;
    end if;

    v_seasonality := 0;
    if v_month in (6, 7, 8, 9) then
      v_seasonality := v_seasonality + 1;
    end if;
    if v_month = 8 then
      v_seasonality := v_seasonality + 1;
    end if;
    if v_month = 12 then
      v_seasonality := v_seasonality + 1;
    end if;
    if v_month = 1 then
      v_seasonality := v_seasonality + 2;
    end if;
    if v_month = 2 then
      v_seasonality := v_seasonality + 1;
    end if;

    v_orders_for_day := v_orders_for_day + v_seasonality;

    if v_orders_for_day > 8 then
      v_orders_for_day := 8;
    end if;

    for v_seller_index in 1..v_orders_for_day loop
      v_is_paid := not (
        v_day >= current_date - 2
        and mod(v_seller_index + extract(day from v_day)::int, 4) = 0
      );

      v_customer_index := 1 + mod(
        extract(doy from v_day)::int + (v_seller_index * 5),
        array_length(v_customer_names, 1)
      );

      v_paid_by_index := 1 + mod(
        extract(day from v_day)::int + v_seller_index + v_month,
        array_length(v_staff_ids, 1)
      );

      v_created_at := (
        v_day::timestamp
        + make_interval(
            hours => 6 + mod(v_seller_index * 2 + extract(day from v_day)::int, 15),
            mins => mod(v_seller_index * 17 + v_month * 9, 60)
          )
      );

      if mod(v_seller_index + v_month + extract(day from v_day)::int, 10) = 0 then
        v_payment_method := 'MOMO';
      elsif mod(v_seller_index + v_month, 4) = 0 then
        v_payment_method := 'BANK_TRANSFER';
      elsif mod(v_seller_index + extract(day from v_day)::int, 5) = 0 then
        v_payment_method := 'CARD';
      else
        v_payment_method := 'CASH';
      end if;

      insert into public.orders (
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
        v_staff_ids[1 + mod(v_seller_index + extract(day from v_day)::int, array_length(v_staff_ids, 1))],
        case when v_is_paid then v_staff_ids[v_paid_by_index] else null end,
        v_customer_names[v_customer_index],
        case when v_is_paid then 'PAID' else 'UNPAID' end,
        v_payment_method,
        0,
        v_created_at,
        v_created_at
      )
      returning id into v_order_id;

      v_line_count := 1 + mod(v_seller_index + extract(day from v_day)::int + v_month, 4);
      if v_month in (12, 1) and mod(v_seller_index, 3) = 0 then
        v_line_count := least(v_line_count + 1, 5);
      end if;

      v_total_amount := 0;

      for v_line_index in 1..v_line_count loop
        v_product_pick := 1 + mod(
          extract(doy from v_day)::int
          + (v_seller_index * 7)
          + (v_line_index * 11)
          + (v_month * 3),
          array_length(v_product_names, 1)
        );

        if v_month in (6, 7, 8, 9) and mod(v_line_index + v_seller_index, 4) = 0 then
          v_product_pick := case
            when mod(v_line_index + extract(day from v_day)::int, 2) = 0 then 1
            else 3
          end;
        elsif v_month = 8 and mod(v_line_index, 3) = 0 then
          v_product_pick := case
            when mod(v_seller_index + v_line_index, 2) = 0 then 5
            else 9
          end;
        elsif v_month in (12, 1) and mod(v_seller_index + v_line_index, 3) = 0 then
          v_product_pick := case
            when mod(v_line_index, 2) = 0 then 16
            else 8
          end;
        elsif v_month = 2 and mod(v_line_index + extract(day from v_day)::int, 5) = 0 then
          v_product_pick := 6;
        end if;

        v_quantity := 1 + mod(v_line_index + v_seller_index + extract(day from v_day)::int, 3);
        if v_product_pick = 16 then
          v_quantity := 1;
        elsif v_product_pick in (1, 2, 8, 9) and mod(v_dow, 2) = 0 then
          v_quantity := least(v_quantity + 1, 4);
        end if;

        v_note_index := 1 + mod(
          v_line_index + v_seller_index + v_month,
          array_length(v_notes, 1)
        );

        insert into public.order_items (
          order_id,
          product_id,
          product_name,
          quantity,
          unit_price,
          note,
          created_at
        )
        values (
          v_order_id,
          v_product_ids[v_product_pick],
          v_product_names[v_product_pick],
          v_quantity,
          v_product_prices[v_product_pick],
          v_notes[v_note_index],
          v_created_at + make_interval(mins => v_line_index)
        );

        v_total_amount := v_total_amount + (v_quantity * v_product_prices[v_product_pick]);
      end loop;

      update public.orders
      set total_amount = v_total_amount,
          updated_at = v_created_at + interval '15 minutes'
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
    'Restaurant demo seeded for % | store=% | orders=% | paid=% | unpaid=% | from % to %',
    v_owner_email,
    v_store_id,
    v_total_orders,
    v_paid_orders,
    v_unpaid_orders,
    date '2025-05-01',
    current_date;
end $$;

commit;


