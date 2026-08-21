-- Admin-only barcode/QR identifier management for Retail/POS.
-- Additive: uses the existing retail_product_identifiers table and store ownership model.

create or replace function public.retail_admin_list_product_identifiers(p_store_product_id uuid)
returns table (
  id uuid,
  product_id uuid,
  identifier_type text,
  identifier_value text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare
  v_product_id uuid;
begin
  if not private.has_role('admin') then
    raise exception 'เฉพาะผู้ดูแลระบบเท่านั้นที่ดูรหัสสินค้าได้';
  end if;

  select store_product.product_id
    into v_product_id
  from public.retail_store_products store_product
  where store_product.id = p_store_product_id
  limit 1;

  if v_product_id is null then
    raise exception 'ไม่พบสินค้าของร้านค้าที่เลือก';
  end if;

  return query
  select identifier.id, identifier.product_id, identifier.identifier_type,
         identifier.identifier_value, identifier.created_at
  from public.retail_product_identifiers identifier
  where identifier.product_id = v_product_id
  order by identifier.identifier_type, identifier.identifier_value
  limit 100;
end;
$$;

create or replace function public.retail_admin_upsert_product_identifier(
  p_store_product_id uuid,
  p_identifier_type text,
  p_identifier_value text
)
returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_product_id uuid;
  v_type text := lower(nullif(btrim(coalesce(p_identifier_type, '')), ''));
  v_value text := nullif(btrim(coalesce(p_identifier_value, '')), '');
  v_existing public.retail_product_identifiers%rowtype;
  v_id uuid;
begin
  if not private.has_role('admin') then
    raise exception 'เฉพาะผู้ดูแลระบบเท่านั้นที่จัดการรหัสสินค้าได้';
  end if;
  if v_type not in ('barcode', 'qr', 'external', 'sku') then
    raise exception 'ประเภทรหัสสินค้าไม่รองรับ';
  end if;
  if v_value is null or char_length(v_value) > 160 then
    raise exception 'รหัสสินค้าต้องมีความยาว 1–160 ตัวอักษร';
  end if;

  select store_product.product_id
    into v_product_id
  from public.retail_store_products store_product
  where store_product.id = p_store_product_id
  limit 1;

  if v_product_id is null then
    raise exception 'ไม่พบสินค้าของร้านค้าที่เลือก';
  end if;

  select identifier.*
    into v_existing
  from public.retail_product_identifiers identifier
  where identifier.identifier_type = v_type
    and lower(identifier.identifier_value) = lower(v_value)
  for update;

  if found and v_existing.product_id <> v_product_id then
    raise exception 'รหัสนี้ถูกผูกกับสินค้าอื่นแล้ว';
  end if;
  if found then
    return v_existing.id;
  end if;

  insert into public.retail_product_identifiers(product_id, identifier_type, identifier_value)
  values (v_product_id, v_type, v_value)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.retail_admin_delete_product_identifier(p_identifier_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if not private.has_role('admin') then
    raise exception 'เฉพาะผู้ดูแลระบบเท่านั้นที่ลบรหัสสินค้าได้';
  end if;
  delete from public.retail_product_identifiers where id = p_identifier_id;
  return found;
end;
$$;

revoke all on function public.retail_admin_list_product_identifiers(uuid) from public, anon;
revoke all on function public.retail_admin_upsert_product_identifier(uuid, text, text) from public, anon;
revoke all on function public.retail_admin_delete_product_identifier(uuid) from public, anon;
grant execute on function public.retail_admin_list_product_identifiers(uuid) to authenticated;
grant execute on function public.retail_admin_upsert_product_identifier(uuid, text, text) to authenticated;
grant execute on function public.retail_admin_delete_product_identifier(uuid) to authenticated;
