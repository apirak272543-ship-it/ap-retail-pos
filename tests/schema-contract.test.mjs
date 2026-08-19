import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const foundation = await readFile(new URL('../supabase/migrations/20260819_001_retail_pos_foundation.sql', import.meta.url), 'utf8');
const securityRemediation = await readFile(new URL('../supabase/migrations/20260819_002_restrict_retail_rpcs.sql', import.meta.url), 'utf8');

const requiredTables = [
  'retail_products',
  'retail_product_identifiers',
  'retail_store_products',
  'retail_inventory_balances',
  'retail_inventory_movements',
  'retail_pos_sales',
  'retail_pos_sale_items',
  'retail_delivery_orders',
  'retail_delivery_order_items',
];

for (const table of requiredTables) {
  assert.match(foundation, new RegExp(`create table if not exists public\\.${table} \\(`));
  assert.match(foundation, new RegExp(`alter table public\\.${table} enable row level security;`));
}

assert.match(foundation, /create or replace function public\.retail_create_pos_sale\(/);
assert.match(foundation, /for update;/);
assert.match(foundation, /idempotency_key uuid not null/);
assert.match(foundation, /quantity_delta numeric\(14,3\) not null check \(quantity_delta <> 0\)/);
assert.match(foundation, /private\.owns_store\(store_id\)/);
assert.match(foundation, /revoke all on function public\.retail_create_pos_sale\(text, jsonb, uuid\) from anon;/);
assert.match(securityRemediation, /revoke all on function public\.retail_get_my_context\(\) from anon;/);
assert.match(securityRemediation, /grant execute on function public\.retail_create_pos_sale\(text, jsonb, uuid\) to authenticated;/);

console.log('Retail schema contract checks passed.');
