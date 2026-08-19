-- Explicit remediation: Supabase default function privileges may leave anon executable.
revoke all on function public.retail_list_customer_stores() from anon;
revoke all on function public.retail_list_customer_products(text, text, text) from anon;
revoke all on function public.retail_create_customer_delivery_order(text, jsonb, text, text, text, uuid) from anon;
revoke all on function public.retail_release_customer_delivery_reservation(text, text) from anon;
revoke all on function public.retail_commit_customer_delivery_reservation(text) from anon;

grant execute on function public.retail_list_customer_stores() to authenticated;
grant execute on function public.retail_list_customer_products(text, text, text) to authenticated;
grant execute on function public.retail_create_customer_delivery_order(text, jsonb, text, text, text, uuid) to authenticated;
grant execute on function public.retail_release_customer_delivery_reservation(text, text) to authenticated;
grant execute on function public.retail_commit_customer_delivery_reservation(text) to authenticated;
