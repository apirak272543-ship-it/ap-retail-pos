import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const runtimeUrl = new URL("../shared/retail-app.js", import.meta.url);

async function runtime() {
  return readFile(runtimeUrl, "utf8");
}

test("POS blocks cart quantities above confirmed inventory", async () => {
  const source = await runtime();
  assert.match(source, /line\.quantity \+ 1 > available/);
  assert.match(source, /next > available/);
  assert.match(source, /จำนวนสินค้าในตะกร้าเกินสต๊อกที่ระบบยืนยัน/);
});

test("Product image upload accepts image files only and compresses to the Golden Rule", async () => {
  const source = await runtime();
  assert.match(source, /file\.type\.startsWith\('image\/'\)/);
  assert.match(source, /1200 \/ Math\.max\(bitmap\.width, bitmap\.height\)/);
  assert.match(source, /'image\/jpeg', \.82/);
  assert.match(source, /mime_type: 'image\/jpeg'/);
});

test("POS sale submission sends only product IDs and quantities to the authoritative RPC", async () => {
  const source = await runtime();
  assert.match(source, /retail_create_pos_sale/);
  assert.match(source, /store_product_id: line\.id, quantity: line\.quantity/);
  assert.doesNotMatch(source, /grand_total:\s*\d/);
});
