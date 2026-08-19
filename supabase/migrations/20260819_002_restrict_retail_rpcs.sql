-- Security remediation discovered by post-migration advisor audit.
-- This project has explicit default EXECUTE grants to anon, so PUBLIC revoke alone is insufficient.

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
