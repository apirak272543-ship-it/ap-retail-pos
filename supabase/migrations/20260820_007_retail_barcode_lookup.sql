CREATE OR REPLACE FUNCTION public.retail_find_store_product_by_identifier(p_identifier text)
RETURNS TABLE (
  id uuid,
  name text,
  sku text,
  price numeric,
  unit_name text,
  image_url text,
  available_quantity numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private, pg_temp
AS $$
DECLARE
  v_store_id text := public.retail_get_my_context() ->> 'store_id';
  v_identifier text := nullif(btrim(coalesce(p_identifier, '')), '');
BEGIN
  IF v_identifier IS NULL OR char_length(v_identifier) > 160 THEN
    RAISE EXCEPTION 'รหัสบาร์โค้ดหรือ SKU ไม่ถูกต้อง';
  END IF;
  RETURN QUERY
  SELECT sp.id, p.name, sp.store_sku, sp.selling_price, p.unit_name, p.image_url,
         greatest(b.on_hand_quantity - b.reserved_quantity, 0)
  FROM public.retail_store_products sp
  JOIN public.retail_products p ON p.id = sp.product_id
  JOIN public.retail_inventory_balances b ON b.store_product_id = sp.id
  WHERE sp.store_id = v_store_id
    AND sp.active IS TRUE
    AND p.approval_status = 'active'
    AND (lower(coalesce(sp.store_sku, '')) = lower(v_identifier)
      OR EXISTS (SELECT 1 FROM public.retail_product_identifiers i WHERE i.product_id = p.id AND lower(i.identifier_value) = lower(v_identifier)))
  ORDER BY CASE WHEN lower(coalesce(sp.store_sku, '')) = lower(v_identifier) THEN 0 ELSE 1 END, sp.created_at
  LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.retail_find_store_product_by_identifier(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retail_find_store_product_by_identifier(text) TO authenticated;
