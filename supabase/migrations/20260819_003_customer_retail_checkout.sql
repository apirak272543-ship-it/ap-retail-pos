-- AP Retail POS / Customer retail ordering bridge.
-- Additive only: no existing AP Service table, policy or food-order RPC is replaced.

alter table public.retail_delivery_orders
  add column if not exists reservation_status text not null default 'reserved'
    check (reservation_status in ('reserved', 'released', 'committed')),
  add column if not exists reservation_updated_at timestamptz not null default now();

alter table public.retail_inventory_movements
  add column if not exists reference_retail_delivery_order_id uuid
    references public.retail_delivery_orders(id) on delete restrict;

alter table public.retail_inventory_movements
  drop constraint if exists retail_inventory_movements_quantity_delta_check;

alter table public.retail_inventory_movements
  add constraint retail_inventory_movements_quantity_delta_check check (quantity_delta is not null);

create index if not exists retail_delivery_orders_customer_created_idx
  on public.retail_delivery_orders (customer_id, created_at desc);

create or replace function public.retail_list_customer_stores()
returns table (
  store_id text,
  store_name text,
  pickup_address text
)
language plpgsql
stable
security definer
set search_path = public, private
as $$
begin
  if auth.uid() is null or not private.has_role('customer') then
    raise exception 'ต้องเข้าสู่ระบบด้วยบัญชีลูกค้าก่อนดูสินค้าทั่วไป';
  end if;

  return query
  select distinct
    store.id,
    store.name,
    coalesce(nullif(btrim(store.location ->> 'address'), ''), store.name)
  from public.stores store
  join public.retail_store_products store_product
    on store_product.store_id = store.id
   and store_product.active is true
  join public.retail_products product
    on product.id = store_product.product_id
   and product.approval_status = 'active'
  join public.retail_inventory_balances balance
    on balance.store_product_id = store_product.id
   and balance.on_hand_quantity > balance.reserved_quantity
  where store.active is true
    and store.emergency_closed is false
  order by store.name
  limit 200;
end;
$$;

create or replace function public.retail_list_customer_products(
  p_store_id text,
  p_search text default '',
  p_category text default null
)
returns table (
  store_product_id uuid,
  name text,
  unit_name text,
  selling_price numeric,
  image_url text,
  category_name text,
  in_stock boolean
)
language plpgsql
stable
security definer
set search_path = public, private
as $$
begin
  if auth.uid() is null or not private.has_role('customer') then
    raise exception 'ต้องเข้าสู่ระบบด้วยบัญชีลูกค้าก่อนดูสินค้าทั่วไป';
  end if;
  if p_store_id is null or btrim(p_store_id) = '' then
    raise exception 'กรุณาเลือกร้านค้า';
  end if;

  return query
  select
    store_product.id,
    product.name,
    product.unit_name,
    store_product.selling_price,
    product.image_url,
    product.category_name,
    balance.on_hand_quantity > balance.reserved_quantity
  from public.stores store
  join public.retail_store_products store_product
    on store_product.store_id = store.id
   and store_product.active is true
  join public.retail_products product
    on product.id = store_product.product_id
   and product.approval_status = 'active'
  join public.retail_inventory_balances balance
    on balance.store_product_id = store_product.id
  where store.id = btrim(p_store_id)
    and store.active is true
    and store.emergency_closed is false
    and (
      coalesce(btrim(p_search), '') = ''
      or product.name ilike '%' || btrim(p_search) || '%'
      or coalesce(product.brand_name, '') ilike '%' || btrim(p_search) || '%'
    )
    and (nullif(btrim(p_category), '') is null or product.category_name = nullif(btrim(p_category), ''))
  order by product.category_name nulls last, product.name
  limit 500;
end;
$$;

create or replace function public.retail_create_customer_delivery_order(
  p_store_id text,
  p_lines jsonb,
  p_delivery_address text,
  p_payment_method text,
  p_customer_name text default '',
  p_idempotency_key uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_location jsonb;
  v_store public.stores%rowtype;
  v_order public.delivery_orders%rowtype;
  v_retail_order public.retail_delivery_orders%rowtype;
  v_line record;
  v_store_product record;
  v_balance public.retail_inventory_balances%rowtype;
  v_subtotal numeric(12,2) := 0;
  v_requested_count integer;
  v_validated_count integer := 0;
  v_status text;
  v_customer_name text;
begin
  if v_customer_id is null or not private.has_role('customer') then
    raise exception 'ต้องเข้าสู่ระบบด้วยบัญชีลูกค้าก่อนสั่งซื้อ';
  end if;
  if not private.account_feature_enabled(v_customer_id, 'ordering') then
    raise exception 'บัญชีนี้ถูกระงับการสั่งซื้อ กรุณาติดต่อผู้ดูแลระบบ';
  end if;
  if p_payment_method = 'เงินสดปลายทาง (COD)'
    and not private.account_feature_enabled(v_customer_id, 'cash_on_delivery') then
    raise exception 'บัญชีนี้ไม่ได้รับสิทธิ์ชำระเงินปลายทาง กรุณาเลือกชำระผ่าน QR / แนบสลิป';
  end if;
  if p_store_id is null or btrim(p_store_id) = ''
    or p_delivery_address is null or btrim(p_delivery_address) = '' then
    raise exception 'กรุณาระบุร้านค้าและที่อยู่จัดส่ง';
  end if;
  if p_payment_method not in ('เงินสดปลายทาง (COD)', 'โอนผ่าน QR / แนบสลิป') then
    raise exception 'วิธีชำระเงินไม่อยู่ในรายการที่อนุญาต';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) > 100 then
    raise exception 'รายการสินค้าทั่วไปไม่ถูกต้อง';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_lines) as x(store_product_id uuid, quantity numeric)
    where store_product_id is null or quantity is null or quantity <= 0 or quantity > 999
      or quantity <> trunc(quantity)
  ) then
    raise exception 'สินค้าและจำนวนต้องอยู่ในช่วงที่อนุญาต';
  end if;

  select * into v_retail_order
  from public.retail_delivery_orders
  where customer_id = v_customer_id and idempotency_key = p_idempotency_key;
  if found then
    select * into v_order from public.delivery_orders where id = v_retail_order.delivery_order_id;
    return jsonb_build_object(
      'id', v_order.id,
      'status', v_order.status,
      'total', v_order.total,
      'delivery_fee', v_order.delivery_fee,
      'payable', v_order.payable,
      'retail_order_id', v_retail_order.id,
      'reservation_status', v_retail_order.reservation_status
    );
  end if;

  select * into v_store
  from public.stores
  where id = btrim(p_store_id) and active is true and emergency_closed is false;
  if not found then
    raise exception 'ร้านค้าไม่พร้อมรับออร์เดอร์';
  end if;
  select location into v_customer_location
  from public.user_profiles
  where user_id = v_customer_id;
  if v_customer_location is null then
    raise exception 'กรุณาบันทึกตำแหน่งจัดส่งในหน้าโปรไฟล์ก่อนสั่งซื้อ';
  end if;
  select count(distinct store_product_id) into v_requested_count
  from jsonb_to_recordset(p_lines) as x(store_product_id uuid, quantity numeric);
  if v_requested_count <> jsonb_array_length(p_lines) then
    raise exception 'พบสินค้าซ้ำในตะกร้า กรุณาลองใหม่อีกครั้ง';
  end if;

  for v_line in
    select store_product_id, quantity
    from jsonb_to_recordset(p_lines) as x(store_product_id uuid, quantity numeric)
    order by store_product_id
  loop
    select store_product.id, store_product.selling_price, product.name, product.unit_name
      into v_store_product
    from public.retail_store_products store_product
    join public.retail_products product on product.id = store_product.product_id
    where store_product.id = v_line.store_product_id
      and store_product.store_id = v_store.id
      and store_product.active is true
      and product.approval_status = 'active'
    for update of store_product;
    if not found then
      raise exception 'มีสินค้าไม่พร้อมขายหรือไม่ได้อยู่ในร้านค้าที่เลือก';
    end if;
    select * into v_balance
    from public.retail_inventory_balances
    where store_product_id = v_store_product.id
    for update;
    if not found or v_balance.on_hand_quantity - v_balance.reserved_quantity < v_line.quantity then
      raise exception 'สินค้า % มีจำนวนคงเหลือไม่เพียงพอ', v_store_product.name;
    end if;
    v_subtotal := v_subtotal + (v_store_product.selling_price * v_line.quantity);
    v_validated_count := v_validated_count + 1;
  end loop;
  if v_validated_count <> v_requested_count then
    raise exception 'ไม่สามารถตรวจสอบรายการสินค้าได้ครบถ้วน';
  end if;

  v_status := case when p_payment_method = 'โอนผ่าน QR / แนบสลิป'
    then 'รอตรวจสอบการชำระเงิน' else 'ร้านค้ารับออร์เดอร์' end;
  v_customer_name := left(coalesce(nullif(btrim(p_customer_name), ''), auth.jwt() ->> 'email', ''), 160);
  insert into public.delivery_orders (
    customer_id, customer_email, customer_name, store_id, store_name, service_type,
    status, total, payable, delivery_fee, payment_method, delivery_address,
    delivery_location, ordered_at
  ) values (
    v_customer_id, coalesce(auth.jwt() ->> 'email', ''), v_customer_name,
    v_store.id, v_store.name, 'retail', v_status, v_subtotal, 0, 0,
    p_payment_method, left(btrim(p_delivery_address), 1000), v_customer_location, now()
  ) returning * into v_order;

  insert into public.retail_delivery_orders (
    delivery_order_id, store_id, customer_id, idempotency_key, quoted_subtotal,
    reservation_status, reservation_updated_at
  ) values (
    v_order.id, v_store.id, v_customer_id, p_idempotency_key, v_subtotal, 'reserved', now()
  ) returning * into v_retail_order;

  for v_line in
    select store_product_id, quantity
    from jsonb_to_recordset(p_lines) as x(store_product_id uuid, quantity numeric)
    order by store_product_id
  loop
    select store_product.id, store_product.selling_price, product.name, product.unit_name
      into v_store_product
    from public.retail_store_products store_product
    join public.retail_products product on product.id = store_product.product_id
    where store_product.id = v_line.store_product_id
    for update of store_product;
    select * into v_balance
    from public.retail_inventory_balances
    where store_product_id = v_store_product.id
    for update;

    insert into public.retail_delivery_order_items (
      retail_delivery_order_id, store_product_id, product_name_snapshot,
      unit_name_snapshot, unit_price, quantity, line_total
    ) values (
      v_retail_order.id, v_store_product.id, v_store_product.name,
      v_store_product.unit_name, v_store_product.selling_price, v_line.quantity,
      v_store_product.selling_price * v_line.quantity
    );
    insert into public.delivery_order_items (order_id, item_id, name, emoji, unit_price, quantity, options)
    values (
      v_order.id, v_store_product.id::text, v_store_product.name, '🛍️',
      v_store_product.selling_price, v_line.quantity::integer,
      jsonb_build_object('channel', 'retail', 'unit_name', v_store_product.unit_name)
    );
    update public.retail_inventory_balances
    set reserved_quantity = v_balance.reserved_quantity + v_line.quantity,
        updated_at = now()
    where store_product_id = v_store_product.id;
    insert into public.retail_inventory_movements (
      store_product_id, movement_type, quantity_delta, on_hand_before, on_hand_after,
      reserved_before, reserved_after, reason, reference_retail_delivery_order_id, actor_id
    ) values (
      v_store_product.id, 'reserve', 0, v_balance.on_hand_quantity, v_balance.on_hand_quantity,
      v_balance.reserved_quantity, v_balance.reserved_quantity + v_line.quantity,
      'จองสต๊อกสำหรับคำสั่งซื้อจัดส่ง', v_retail_order.id, v_customer_id
    );
  end loop;

  return jsonb_build_object(
    'id', v_order.id,
    'status', v_order.status,
    'total', v_order.total,
    'delivery_fee', v_order.delivery_fee,
    'payable', v_order.payable,
    'retail_order_id', v_retail_order.id,
    'reservation_status', v_retail_order.reservation_status
  );
end;
$$;

create or replace function public.retail_release_customer_delivery_reservation(
  p_delivery_order_id text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_retail_order public.retail_delivery_orders%rowtype;
  v_delivery_order public.delivery_orders%rowtype;
  v_item record;
  v_balance public.retail_inventory_balances%rowtype;
begin
  select * into v_retail_order
  from public.retail_delivery_orders
  where delivery_order_id = p_delivery_order_id
  for update;
  if not found then raise exception 'ไม่พบคำสั่งซื้อ Retail'; end if;
  if not (private.has_role('admin') or private.owns_store(v_retail_order.store_id)) then
    raise exception 'ไม่มีสิทธิ์คืนสต๊อกของคำสั่งซื้อนี้';
  end if;
  if v_retail_order.reservation_status = 'released' then
    return jsonb_build_object('delivery_order_id', p_delivery_order_id, 'reservation_status', 'released');
  end if;
  if v_retail_order.reservation_status <> 'reserved' then
    raise exception 'คำสั่งซื้อนี้ไม่อยู่ในสถานะคืนสต๊อกได้';
  end if;
  select * into v_delivery_order from public.delivery_orders where id = p_delivery_order_id;
  if not found or lower(v_delivery_order.status) not in ('cancelled', 'canceled', 'ยกเลิก', 'ยกเลิกโดยลูกค้า', 'ยกเลิกโดยร้าน', 'ปฏิเสธ', 'ปฏิเสธออร์เดอร์') then
    raise exception 'ต้องเปลี่ยนสถานะคำสั่งซื้อเป็นยกเลิกหรือปฏิเสธก่อนคืนสต๊อก';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 240 then
    raise exception 'กรุณาระบุเหตุผลการคืนสต๊อก';
  end if;
  for v_item in select * from public.retail_delivery_order_items where retail_delivery_order_id = v_retail_order.id loop
    select * into v_balance from public.retail_inventory_balances where store_product_id = v_item.store_product_id for update;
    update public.retail_inventory_balances
    set reserved_quantity = greatest(v_balance.reserved_quantity - v_item.quantity, 0), updated_at = now()
    where store_product_id = v_item.store_product_id;
    insert into public.retail_inventory_movements (
      store_product_id, movement_type, quantity_delta, on_hand_before, on_hand_after,
      reserved_before, reserved_after, reason, reference_retail_delivery_order_id, actor_id
    ) values (
      v_item.store_product_id, 'release', 0, v_balance.on_hand_quantity, v_balance.on_hand_quantity,
      v_balance.reserved_quantity, greatest(v_balance.reserved_quantity - v_item.quantity, 0),
      btrim(p_reason), v_retail_order.id, auth.uid()
    );
  end loop;
  update public.retail_delivery_orders
  set reservation_status = 'released', reservation_updated_at = now()
  where id = v_retail_order.id;
  return jsonb_build_object('delivery_order_id', p_delivery_order_id, 'reservation_status', 'released');
end;
$$;

create or replace function public.retail_commit_customer_delivery_reservation(p_delivery_order_id text)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_retail_order public.retail_delivery_orders%rowtype;
  v_delivery_order public.delivery_orders%rowtype;
  v_item record;
  v_balance public.retail_inventory_balances%rowtype;
begin
  select * into v_retail_order from public.retail_delivery_orders where delivery_order_id = p_delivery_order_id for update;
  if not found then raise exception 'ไม่พบคำสั่งซื้อ Retail'; end if;
  if not (private.has_role('admin') or private.owns_store(v_retail_order.store_id)) then
    raise exception 'ไม่มีสิทธิ์ตัดสต๊อกของคำสั่งซื้อนี้';
  end if;
  if v_retail_order.reservation_status = 'committed' then
    return jsonb_build_object('delivery_order_id', p_delivery_order_id, 'reservation_status', 'committed');
  end if;
  if v_retail_order.reservation_status <> 'reserved' then
    raise exception 'คำสั่งซื้อนี้ไม่อยู่ในสถานะตัดสต๊อกได้';
  end if;
  select * into v_delivery_order from public.delivery_orders where id = p_delivery_order_id;
  if not found or lower(v_delivery_order.status) not in ('delivered', 'completed', 'จัดส่งสำเร็จ', 'เสร็จสิ้น') then
    raise exception 'ต้องเปลี่ยนสถานะคำสั่งซื้อเป็นจัดส่งสำเร็จก่อนตัดสต๊อก';
  end if;
  for v_item in select * from public.retail_delivery_order_items where retail_delivery_order_id = v_retail_order.id loop
    select * into v_balance from public.retail_inventory_balances where store_product_id = v_item.store_product_id for update;
    update public.retail_inventory_balances
    set on_hand_quantity = v_balance.on_hand_quantity - v_item.quantity,
        reserved_quantity = v_balance.reserved_quantity - v_item.quantity,
        updated_at = now()
    where store_product_id = v_item.store_product_id;
    insert into public.retail_inventory_movements (
      store_product_id, movement_type, quantity_delta, on_hand_before, on_hand_after,
      reserved_before, reserved_after, reason, reference_retail_delivery_order_id, actor_id
    ) values (
      v_item.store_product_id, 'sale', -v_item.quantity,
      v_balance.on_hand_quantity, v_balance.on_hand_quantity - v_item.quantity,
      v_balance.reserved_quantity, v_balance.reserved_quantity - v_item.quantity,
      'ตัดสต๊อกจากคำสั่งซื้อจัดส่งที่สำเร็จ', v_retail_order.id, auth.uid()
    );
  end loop;
  update public.retail_delivery_orders
  set reservation_status = 'committed', reservation_updated_at = now()
  where id = v_retail_order.id;
  return jsonb_build_object('delivery_order_id', p_delivery_order_id, 'reservation_status', 'committed');
end;
$$;

revoke all on function public.retail_list_customer_stores() from public;
revoke all on function public.retail_list_customer_products(text, text, text) from public;
revoke all on function public.retail_create_customer_delivery_order(text, jsonb, text, text, text, uuid) from public;
revoke all on function public.retail_release_customer_delivery_reservation(text, text) from public;
revoke all on function public.retail_commit_customer_delivery_reservation(text) from public;
grant execute on function public.retail_list_customer_stores() to authenticated;
grant execute on function public.retail_list_customer_products(text, text, text) to authenticated;
grant execute on function public.retail_create_customer_delivery_order(text, jsonb, text, text, text, uuid) to authenticated;
grant execute on function public.retail_release_customer_delivery_reservation(text, text) to authenticated;
grant execute on function public.retail_commit_customer_delivery_reservation(text) to authenticated;

comment on function public.retail_create_customer_delivery_order(text, jsonb, text, text, text, uuid)
  is 'Customer retail checkout: validates product price and availability, reserves stock atomically and writes delivery order snapshots.';
