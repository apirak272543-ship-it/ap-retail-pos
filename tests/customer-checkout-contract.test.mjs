import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const checkoutMigration = await readFile(new URL('supabase/migrations/20260819_003_customer_retail_checkout.sql', root), 'utf8');
const privilegeMigration = await readFile(new URL('supabase/migrations/20260819_004_restrict_customer_retail_rpcs.sql', root), 'utf8');

assert.match(checkoutMigration, /create or replace function public\.retail_list_customer_stores\(\)/);
assert.match(checkoutMigration, /create or replace function public\.retail_list_customer_products\(/);
assert.match(checkoutMigration, /create or replace function public\.retail_create_customer_delivery_order\(/);
assert.match(checkoutMigration, /idempotency_key uuid default gen_random_uuid\(\)/);
assert.match(checkoutMigration, /for update of store_product;/);
assert.match(checkoutMigration, /for update;/);
assert.match(checkoutMigration, /reserved_quantity = v_balance\.reserved_quantity \+ v_line\.quantity/);
assert.match(checkoutMigration, /'reserve', 0/);
assert.match(checkoutMigration, /service_type,\n\s*status, total, payable, delivery_fee/);
assert.match(checkoutMigration, /v_status, v_subtotal, 0, 0,/);
assert.match(checkoutMigration, /private\.has_role\('customer'\)/);
assert.match(checkoutMigration, /create or replace function public\.retail_release_customer_delivery_reservation\(/);
assert.match(checkoutMigration, /create or replace function public\.retail_commit_customer_delivery_reservation\(/);

const functions = [
  'retail_list_customer_stores\\(\\)',
  'retail_list_customer_products\\(text, text, text\\)',
  'retail_create_customer_delivery_order\\(text, jsonb, text, text, text, uuid\\)',
  'retail_release_customer_delivery_reservation\\(text, text\\)',
  'retail_commit_customer_delivery_reservation\\(text\\)',
];
for (const signature of functions) {
  assert.match(privilegeMigration, new RegExp(`revoke all on function public\\.${signature} from anon;`));
  assert.match(privilegeMigration, new RegExp(`grant execute on function public\\.${signature} to authenticated;`));
}

console.log('Customer retail checkout schema contract checks passed.');
