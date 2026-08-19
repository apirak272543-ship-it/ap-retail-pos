-- AP Retail POS foundation migration
-- Additive only: creates new Retail tables, policies and RPCs. Existing AP Service tables are not altered.

create table if not exists public.retail_products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 160),
  brand_name text,
  category_name text,
  unit_name text not null check (char_length(btrim(unit_name)) between 1 and 80),
  image_url text,
  approval_status text not null default 'active'
    check (approval_status in ('active', 'pending', 'archived')),
  submitted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.retail_product_identifiers (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.retail_products(id) on delete restrict,
  identifier_type text not null check (identifier_type in ('barcode', 'qr', 'external', 'sku')),
  identifier_value text not null check (char_length(btrim(identifier_value)) between 1 and 160),
  created_at timestamptz not null default now(),
  unique (identifier_type, identifier_value)
);

create table if not exists public.retail_store_products (
  id uuid primary key default gen_random_uuid(),
  store_id text not null references public.stores(id) on delete restrict,
  product_id uuid not null references public.retail_products(id) on delete restrict,
  store_sku text,
  selling_price numeric(12,2) not null check (selling_price >= 0),
  cost_price numeric(12,2) check (cost_price >= 0),
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, product_id),
  unique (store_id, store_sku)
);

create table if not exists public.retail_inventory_balances (
  store_product_id uuid primary key references public.retail_store_products(id) on delete restrict,
  on_hand_quantity numeric(14,3) not null default 0 check (on_hand_quantity >= 0),
  reserved_quantity numeric(14,3) not null default 0 check (reserved_quantity >= 0),
  minimum_quantity numeric(14,3) not null default 0 check (minimum_quantity >= 0),
  updated_at timestamptz not null default now(),
  check (reserved_quantity <= on_hand_quantity)
);

create table if not exists public.retail_pos_sales (
  id uuid primary key default gen_random_uuid(),
  store_id text not null references public.stores(id) on delete restrict,
  sale_number text not null unique,
  idempotency_key uuid not null default gen_random_uuid(),
  payment_method text not null check (payment_method in ('cash', 'transfer', 'card')),
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount_total numeric(12,2) not null default 0 check (discount_total >= 0),
  grand_total numeric(12,2) not null default 0 check (grand_total >= 0),
  completed_by uuid not null references auth.users(id) on delete restrict,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (store_id, idempotency_key)
);

create table if not exists public.retail_pos_sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.retail_pos_sales(id) on delete restrict,
  store_product_id uuid not null references public.retail_store_products(id) on delete restrict,
  product_name_snapshot text not null,
  sku_snapshot text,
  unit_name_snapshot text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity numeric(14,3) not null check (quantity > 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.retail_inventory_movements (
  id uuid primary key default gen_random_uuid(),
  store_product_id uuid not null references public.retail_store_products(id) on delete restrict,
  movement_type text not null check (movement_type in ('receipt', 'sale', 'return', 'reserve', 'release', 'adjustment', 'damage', 'loss')),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  on_hand_before numeric(14,3) not null check (on_hand_before >= 0),
  on_hand_after numeric(14,3) not null check (on_hand_after >= 0),
  reserved_before numeric(14,3) not null check (reserved_before >= 0),
  reserved_after numeric(14,3) not null check (reserved_after >= 0),
  reason text not null check (char_length(btrim(reason)) between 1 and 240),
  reference_sale_id uuid references public.retail_pos_sales(id) on delete restrict,
  actor_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.retail_delivery_orders (
  id uuid primary key default gen_random_uuid(),
  delivery_order_id text not null unique references public.delivery_orders(id) on delete restrict,
  store_id text not null references public.stores(id) on delete restrict,
  customer_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key uuid not null default gen_random_uuid(),
  quoted_subtotal numeric(12,2) not null check (quoted_subtotal >= 0),
  created_at timestamptz not null default now(),
  unique (customer_id, idempotency_key)
);

create table if not exists public.retail_delivery_order_items (
  id uuid primary key default gen_random_uuid(),
  retail_delivery_order_id uuid not null references public.retail_delivery_orders(id) on delete restrict,
  store_product_id uuid not null references public.retail_store_products(id) on delete restrict,
  product_name_snapshot text not null,
  unit_name_snapshot text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity numeric(14,3) not null check (quantity > 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  created_at timestamptz not null default now()
);

create index if not exists retail_products_name_idx on public.retail_products (lower(name));
create index if not exists retail_store_products_store_active_idx on public.retail_store_products (store_id, active);
create index if not exists retail_inventory_movements_store_product_created_idx on public.retail_inventory_movements (store_product_id, created_at desc);
create index if not exists retail_pos_sales_store_created_idx on public.retail_pos_sales (store_id, created_at desc);
create index if not exists retail_pos_sale_items_sale_idx on public.retail_pos_sale_items (sale_id);
create index if not exists retail_delivery_orders_store_idx on public.retail_delivery_orders (store_id, created_at desc);

alter table public.retail_products enable row level security;
alter table public.retail_product_identifiers enable row level security;
alter table public.retail_store_products enable row level security;
alter table public.retail_inventory_balances enable row level security;
alter table public.retail_pos_sales enable row level security;
alter table public.retail_pos_sale_items enable row level security;
alter table public.retail_inventory_movements enable row level security;
alter table public.retail_delivery_orders enable row level security;
alter table public.retail_delivery_order_items enable row level security;

create policy retail_products_read_active_or_owner_or_admin
  on public.retail_products for select to authenticated
  using (
    approval_status = 'active'
    or submitted_by = auth.uid()
    or private.has_role('admin')
  );

create policy retail_products_admin_governance
  on public.retail_products for all to authenticated
  using (private.has_role('admin'))
  with check (private.has_role('admin'));

create policy retail_product_identifiers_read_active_or_admin
  on public.retail_product_identifiers for select to authenticated
  using (
    private.has_role('admin')
    or exists (
      select 1 from public.retail_products product
      where product.id = retail_product_identifiers.product_id
        and (product.approval_status = 'active' or product.submitted_by = auth.uid())
    )
  );

create policy retail_product_identifiers_admin_governance
  on public.retail_product_identifiers for all to authenticated
  using (private.has_role('admin'))
  with check (private.has_role('admin'));

create policy retail_store_products_read_customer_owner_or_admin
  on public.retail_store_products for select to authenticated
  using (
    private.owns_store(store_id)
    or private.has_role('admin')
    or (
      active is true
      and exists (
        select 1 from public.retail_products product
        where product.id = retail_store_products.product_id
          and product.approval_status = 'active'
      )
      and exists (
        select 1 from public.stores store
        where store.id = retail_store_products.store_id
          and store.active is true
          and store.emergency_closed is false
      )
    )
  );

create policy retail_inventory_balances_read_owner_or_admin
  on public.retail_inventory_balances for select to authenticated
  using (
    private.has_role('admin')
    or exists (
      select 1 from public.retail_store_products store_product
      where store_product.id = retail_inventory_balances.store_product_id
        and private.owns_store(store_product.store_id)
    )
  );

create policy retail_pos_sales_read_owner_or_admin
  on public.retail_pos_sales for select to authenticated
  using (private.owns_store(store_id) or private.has_role('admin'));

create policy retail_pos_sale_items_read_owner_or_admin
  on public.retail_pos_sale_items for select to authenticated
  using (
    private.has_role('admin')
    or exists (
      select 1 from public.retail_pos_sales sale
      where sale.id = retail_pos_sale_items.sale_id
        and private.owns_store(sale.store_id)
    )
  );

create policy retail_inventory_movements_read_owner_or_admin
  on public.retail_inventory_movements for select to authenticated
  using (
    private.has_role('admin')
    or exists (
      select 1 from public.retail_store_products store_product
      where store_product.id = retail_inventory_movements.store_product_id
        and private.owns_store(store_product.store_id)
    )
  );

create policy retail_delivery_orders_read_participant_or_admin
  on public.retail_delivery_orders for select to authenticated
  using (
    customer_id = auth.uid()
    or private.owns_store(store_id)
    or private.has_role('admin')
  );

create policy retail_delivery_order_items_read_participant_or_admin
  on public.retail_delivery_order_items for select to authenticated
  using (
    private.has_role('admin')
    or exists (
      select 1 from public.retail_delivery_orders retail_order
      where retail_order.id = retail_delivery_order_items.retail_delivery_order_id
        and (retail_order.customer_id = auth.uid() or private.owns_store(retail_order.store_id))
    )
  );

create or replace function public.retail_get_my_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_store public.stores%rowtype;
begin
  if not private.has_role('store_owner') and not private.has_role('admin') then
    raise exception 'Retail POS ต้องใช้สิทธิ์เจ้าของร้านหรือผู้ดูแลระบบ';
  end if;

  select store.* into v_store
  from public.stores store
  where private.owns_store(store.id)
  order by store.name
  limit 1;

  if not found then
    raise exception 'บัญชีนี้ยังไม่มีสาขาที่ได้รับสิทธิ์สำหรับ Retail POS';
  end if;

  return jsonb_build_object(
    'store_id', v_store.id,
    'store_name', v_store.name,
    'store_active', v_store.active and not v_store.emergency_closed
  );
end;
$$;

create or replace function public.retail_list_store_products(
  p_search text default '',
  p_category text default null
)
returns table (
  id uuid,
  name text,
  sku text,
  price numeric,
  unit_name text,
  image_url text,
  category_name text,
  available_quantity numeric
)
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_store_id text;
begin
  v_store_id := public.retail_get_my_context() ->> 'store_id';
  return query
  select
    store_product.id,
    product.name,
    store_product.store_sku,
    store_product.selling_price,
    product.unit_name,
    product.image_url,
    product.category_name,
    greatest(balance.on_hand_quantity - balance.reserved_quantity, 0)
  from public.retail_store_products store_product
  join public.retail_products product on product.id = store_product.product_id
  join public.retail_inventory_balances balance on balance.store_product_id = store_product.id
  where store_product.store_id = v_store_id
    and store_product.active is true
    and product.approval_status = 'active'
    and (
      coalesce(btrim(p_search), '') = ''
      or product.name ilike '%' || btrim(p_search) || '%'
      or coalesce(store_product.store_sku, '') ilike '%' || btrim(p_search) || '%'
    )
    and (nullif(btrim(p_category), '') is null or product.category_name = nullif(btrim(p_category), ''))
  order by product.name
  limit 500;
end;
$$;

create or replace function public.retail_upsert_store_product(p_product jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id text;
  v_product_id uuid;
  v_store_product_id uuid;
  v_name text;
  v_unit_name text;
  v_sku text;
  v_price numeric(12,2);
  v_image_url text;
begin
  if p_product is null or jsonb_typeof(p_product) <> 'object' then
    raise exception 'ข้อมูลสินค้าไม่ถูกต้อง';
  end if;

  v_store_id := public.retail_get_my_context() ->> 'store_id';
  v_name := nullif(btrim(p_product ->> 'name'), '');
  v_unit_name := nullif(btrim(p_product ->> 'unit_name'), '');
  v_sku := nullif(btrim(p_product ->> 'sku'), '');
  v_image_url := nullif(btrim(p_product ->> 'image_url'), '');

  if v_name is null or v_unit_name is null then
    raise exception 'กรุณาระบุชื่อสินค้าและหน่วยนับ';
  end if;

  begin
    v_price := (p_product ->> 'price')::numeric(12,2);
  exception when others then
    raise exception 'ราคาสินค้าไม่ถูกต้อง';
  end;
  if v_price < 0 then
    raise exception 'ราคาสินค้าต้องไม่ติดลบ';
  end if;

  if nullif(btrim(p_product ->> 'id'), '') is not null then
    select store_product.id into v_store_product_id
    from public.retail_store_products store_product
    where store_product.id = (p_product ->> 'id')::uuid
      and store_product.store_id = v_store_id
    for update;
    if not found then
      raise exception 'ไม่พบสินค้าของสาขาที่ได้รับสิทธิ์';
    end if;

    update public.retail_store_products
    set store_sku = v_sku,
        selling_price = v_price,
        updated_at = now()
    where id = v_store_product_id;
    return v_store_product_id;
  end if;

  select product.id into v_product_id
  from public.retail_products product
  where lower(product.name) = lower(v_name)
    and lower(product.unit_name) = lower(v_unit_name)
    and product.approval_status = 'active'
  order by product.created_at
  limit 1;

  if v_product_id is null then
    insert into public.retail_products (name, unit_name, image_url, submitted_by)
    values (v_name, v_unit_name, v_image_url, auth.uid())
    returning id into v_product_id;
  end if;

  insert into public.retail_store_products (store_id, product_id, store_sku, selling_price, created_by)
  values (v_store_id, v_product_id, v_sku, v_price, auth.uid())
  returning id into v_store_product_id;

  insert into public.retail_inventory_balances (store_product_id)
  values (v_store_product_id);

  return v_store_product_id;
end;
$$;

create or replace function public.retail_record_inventory_movement(
  p_store_product_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id text;
  v_balance public.retail_inventory_balances%rowtype;
  v_store_product public.retail_store_products%rowtype;
  v_delta numeric(14,3);
  v_after numeric(14,3);
begin
  v_store_id := public.retail_get_my_context() ->> 'store_id';
  if nullif(btrim(p_reason), '') is null then
    raise exception 'กรุณาระบุเหตุผลการเคลื่อนไหวสต๊อก';
  end if;
  if p_movement_type not in ('receipt', 'adjustment', 'damage', 'loss', 'return') then
    raise exception 'ประเภทการเคลื่อนไหวสต๊อกไม่รองรับ';
  end if;
  if p_quantity is null or p_quantity = 0 then
    raise exception 'จำนวนสต๊อกต้องไม่เป็นศูนย์';
  end if;

  select store_product.* into v_store_product
  from public.retail_store_products store_product
  where store_product.id = p_store_product_id
    and store_product.store_id = v_store_id
  for update;
  if not found then
    raise exception 'ไม่พบสินค้าของสาขาที่ได้รับสิทธิ์';
  end if;

  select balance.* into v_balance
  from public.retail_inventory_balances balance
  where balance.store_product_id = p_store_product_id
  for update;
  if not found then
    raise exception 'ไม่พบยอดสต๊อกสินค้า';
  end if;

  v_delta := case
    when p_movement_type in ('receipt', 'return') then abs(p_quantity)
    when p_movement_type in ('damage', 'loss') then -abs(p_quantity)
    else p_quantity
  end;
  v_after := v_balance.on_hand_quantity + v_delta;
  if v_after < v_balance.reserved_quantity then
    raise exception 'ไม่สามารถลดสต๊อกต่ำกว่าจำนวนที่ถูกจองไว้';
  end if;

  update public.retail_inventory_balances
  set on_hand_quantity = v_after,
      updated_at = now()
  where store_product_id = p_store_product_id;

  insert into public.retail_inventory_movements (
    store_product_id, movement_type, quantity_delta, on_hand_before, on_hand_after,
    reserved_before, reserved_after, reason, actor_id
  ) values (
    p_store_product_id, p_movement_type, v_delta, v_balance.on_hand_quantity, v_after,
    v_balance.reserved_quantity, v_balance.reserved_quantity, btrim(p_reason), auth.uid()
  );

  return jsonb_build_object('store_product_id', p_store_product_id, 'on_hand_quantity', v_after);
end;
$$;

create or replace function public.retail_create_pos_sale(
  p_payment_method text,
  p_lines jsonb,
  p_idempotency_key uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id text;
  v_sale public.retail_pos_sales%rowtype;
  v_line record;
  v_store_product public.retail_store_products%rowtype;
  v_product public.retail_products%rowtype;
  v_balance public.retail_inventory_balances%rowtype;
  v_available numeric(14,3);
  v_line_total numeric(12,2);
  v_subtotal numeric(12,2) := 0;
  v_sale_number text;
begin
  v_store_id := public.retail_get_my_context() ->> 'store_id';
  if p_payment_method not in ('cash', 'transfer', 'card') then
    raise exception 'วิธีรับเงินไม่รองรับ';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'กรุณาเพิ่มสินค้าอย่างน้อยหนึ่งรายการ';
  end if;

  select sale.* into v_sale
  from public.retail_pos_sales sale
  where sale.store_id = v_store_id
    and sale.idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('sale_id', v_sale.id, 'sale_number', v_sale.sale_number, 'grand_total', v_sale.grand_total, 'idempotent_replay', true);
  end if;

  v_sale_number := 'POS-' || to_char(clock_timestamp(), 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.retail_pos_sales (store_id, sale_number, idempotency_key, payment_method, completed_by)
  values (v_store_id, v_sale_number, p_idempotency_key, p_payment_method, auth.uid())
  returning * into v_sale;

  for v_line in
    select lines.store_product_id, sum(lines.quantity)::numeric(14,3) as quantity
    from jsonb_to_recordset(p_lines) as lines(store_product_id uuid, quantity numeric)
    group by lines.store_product_id
  loop
    if v_line.store_product_id is null or v_line.quantity is null or v_line.quantity <= 0 then
      raise exception 'จำนวนสินค้าไม่ถูกต้อง';
    end if;

    select store_product.* into v_store_product
    from public.retail_store_products store_product
    where store_product.id = v_line.store_product_id
      and store_product.store_id = v_store_id
      and store_product.active is true
    for update;
    if not found then
      raise exception 'มีสินค้าที่ไม่พร้อมขายหรือไม่อยู่ในสาขา';
    end if;

    select product.* into v_product
    from public.retail_products product
    where product.id = v_store_product.product_id
      and product.approval_status = 'active';
    if not found then
      raise exception 'สินค้านี้ยังไม่ได้รับอนุมัติให้ขาย';
    end if;

    select balance.* into v_balance
    from public.retail_inventory_balances balance
    where balance.store_product_id = v_store_product.id
    for update;
    if not found then
      raise exception 'ไม่พบยอดสต๊อกสินค้า';
    end if;

    v_available := v_balance.on_hand_quantity - v_balance.reserved_quantity;
    if v_line.quantity > v_available then
      raise exception 'สต๊อกสินค้า % ไม่เพียงพอ', v_product.name;
    end if;

    v_line_total := round(v_store_product.selling_price * v_line.quantity, 2);
    v_subtotal := v_subtotal + v_line_total;

    insert into public.retail_pos_sale_items (
      sale_id, store_product_id, product_name_snapshot, sku_snapshot, unit_name_snapshot,
      unit_price, quantity, line_total
    ) values (
      v_sale.id, v_store_product.id, v_product.name, v_store_product.store_sku, v_product.unit_name,
      v_store_product.selling_price, v_line.quantity, v_line_total
    );

    update public.retail_inventory_balances
    set on_hand_quantity = v_balance.on_hand_quantity - v_line.quantity,
        updated_at = now()
    where store_product_id = v_store_product.id;

    insert into public.retail_inventory_movements (
      store_product_id, movement_type, quantity_delta, on_hand_before, on_hand_after,
      reserved_before, reserved_after, reason, reference_sale_id, actor_id
    ) values (
      v_store_product.id, 'sale', -v_line.quantity, v_balance.on_hand_quantity,
      v_balance.on_hand_quantity - v_line.quantity, v_balance.reserved_quantity,
      v_balance.reserved_quantity, 'ยืนยันการขายหน้าร้าน', v_sale.id, auth.uid()
    );
  end loop;

  update public.retail_pos_sales
  set subtotal = v_subtotal,
      grand_total = v_subtotal
  where id = v_sale.id
  returning * into v_sale;

  return jsonb_build_object('sale_id', v_sale.id, 'sale_number', v_sale.sale_number, 'grand_total', v_sale.grand_total, 'idempotent_replay', false);
end;
$$;

create or replace function public.retail_list_sales(p_limit integer default 50)
returns table (
  id uuid,
  sale_number text,
  payment_method text,
  grand_total numeric,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_store_id text;
begin
  v_store_id := public.retail_get_my_context() ->> 'store_id';
  return query
  select sale.id, sale.sale_number, sale.payment_method, sale.grand_total, sale.created_at
  from public.retail_pos_sales sale
  where sale.store_id = v_store_id
  order by sale.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke all on function public.retail_get_my_context() from public;
revoke all on function public.retail_list_store_products(text, text) from public;
revoke all on function public.retail_upsert_store_product(jsonb) from public;
revoke all on function public.retail_record_inventory_movement(uuid, text, numeric, text) from public;
revoke all on function public.retail_create_pos_sale(text, jsonb, uuid) from public;
revoke all on function public.retail_list_sales(integer) from public;
revoke all on function public.retail_get_my_context() from anon;
revoke all on function public.retail_list_store_products(text, text) from anon;
revoke all on function public.retail_upsert_store_product(jsonb) from anon;
revoke all on function public.retail_record_inventory_movement(uuid, text, numeric, text) from anon;
revoke all on function public.retail_create_pos_sale(text, jsonb, uuid) from anon;
revoke all on function public.retail_list_sales(integer) from anon;

grant execute on function public.retail_get_my_context() to authenticated;
grant execute on function public.retail_list_store_products(text, text) to authenticated;
grant execute on function public.retail_upsert_store_product(jsonb) to authenticated;
grant execute on function public.retail_record_inventory_movement(uuid, text, numeric, text) to authenticated;
grant execute on function public.retail_create_pos_sale(text, jsonb, uuid) to authenticated;
grant execute on function public.retail_list_sales(integer) to authenticated;

comment on table public.retail_products is 'Global retail product catalog. Product price and stock are intentionally stored per store.';
comment on table public.retail_inventory_movements is 'Append-only audit trail. Stock changes only through approved RPCs.';
comment on function public.retail_create_pos_sale(text, jsonb, uuid) is 'Locks inventory, verifies price and quantity server-side, snapshots sale items and records stock movements.';
