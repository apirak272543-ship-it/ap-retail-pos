import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const runtimeUrl = new URL("../shared/retail-app.js", import.meta.url);
const catalogUrl = new URL("../catalog.html", import.meta.url);
const inventoryUrl = new URL("../inventory.html", import.meta.url);
const salesUrl = new URL("../sales.html", import.meta.url);

async function runtime() {
  return readFile(runtimeUrl, "utf8");
}

async function readSource(url) {
  return readFile(url, "utf8");
}

test("POS blocks cart quantities above confirmed inventory", async () => {
  const source = await runtime();
  assert.match(source, /line\.quantity \+ 1 > available/);
  assert.match(source, /next > available/);
  assert.match(source, /จำนวนสินค้าในตะกร้าเกินสต๊อกที่ระบบยืนยัน/);
});

test("Product image upload accepts camera or library images only and compresses to the Golden Rule", async () => {
  const source = await runtime();
  const catalog = await readSource(catalogUrl);
  assert.match(catalog, /id="product-image-library"[^>]*accept="image\/jpeg,image\/png,image\/webp"/);
  assert.match(catalog, /id="product-image-camera"[^>]*capture="environment"/);
  assert.doesNotMatch(catalog, /image[_-]?url[^>]*type="url"/i);
  assert.match(source, /\['image\/jpeg', 'image\/png', 'image\/webp'\]\.includes\(file\.type\)/);
  assert.match(source, /1200 \/ Math\.max\(bitmap\.width, bitmap\.height\)/);
  assert.match(source, /'image\/jpeg', \.82/);
  assert.match(source, /storage\.from\('catalog-media'\)\.upload/);
  assert.match(source, /contentType: 'image\/jpeg'/);
  assert.match(source, /getPublicUrl\(path\)/);
});

test("POS sale submission sends only product IDs and quantities with an idempotency key to the authoritative RPC", async () => {
  const source = await runtime();
  assert.match(source, /retail_create_pos_sale/);
  assert.match(source, /store_product_id: line\.id, quantity: line\.quantity/);
  assert.match(source, /p_idempotency_key: idempotencyKey/);
  assert.match(source, /crypto\.randomUUID\(\)/);
  assert.match(source, /state\.saleSubmissionKey = null/);
  assert.doesNotMatch(source, /p_grand_total/);
});

test("Inventory history and adjustments use the authenticated backend data model with clear empty states", async () => {
  const source = await runtime();
  const inventory = await readSource(inventoryUrl);
  assert.match(inventory, /id="inventory-history"/);
  assert.match(inventory, /value="receipt"/);
  assert.match(inventory, /value="adjustment"/);
  assert.match(inventory, /value="damage"/);
  assert.match(inventory, /value="loss"/);
  assert.match(source, /from\('retail_inventory_movements'\)/);
  assert.match(source, /retail_record_inventory_movement/);
  assert.match(source, /ยังไม่มีการเคลื่อนไหวสต๊อกที่แสดงตามสิทธิ์ของคุณ/);
});

test("Sales reports filter returned data and show line-item detail without synthetic totals", async () => {
  const source = await runtime();
  const sales = await readSource(salesUrl);
  assert.match(sales, /id="sales-date-filter"/);
  assert.match(sales, /id="sales-payment-filter"/);
  assert.match(sales, /id="sale-detail-dialog"/);
  assert.match(source, /from\('retail_pos_sales'\)/);
  assert.match(source, /from\('retail_pos_sale_items'\)/);
  assert.match(source, /function filteredSales\(\)/);
  assert.match(source, /ไม่มีรายการที่ตรงกับตัวกรอง/);
  assert.match(source, /ยอดรวมยังไม่พร้อมจากข้อมูลที่ระบบคืนให้/);
  assert.match(source, /Number\.isFinite\(value\) \? currency\.format\(value\) : '—'/);
});
