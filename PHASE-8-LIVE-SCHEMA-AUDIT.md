# Phase 8 — Live Retail Schema Audit

## ผลการตรวจฐานข้อมูลจริง

การตรวจแบบ read-only เมื่อวันที่ 19 สิงหาคม 2026 ที่ Supabase project `abtsctwfkgzciseppach` พบว่า schema Retail ที่ใช้งานจริงมีชุดตาราง `retail_*` ดังนี้: `retail_products`, `retail_product_identifiers`, `retail_store_products`, `retail_inventory_balances`, `retail_pos_sales`, `retail_pos_sale_items`, `retail_inventory_movements`, `retail_delivery_orders` และ `retail_delivery_order_items` โดยทุกตารางเปิด RLS

ตาราง Retail ทั้งหมดข้างต้นมีจำนวนแถวเป็นศูนย์ในขณะตรวจ จึงไม่มีสินค้า, สต๊อก, การขาย, การเคลื่อนไหวสต๊อก หรือคำสั่งซื้อ Retail จริงที่สามารถใช้เป็นข้อมูลทดสอบ end-to-end โดยไม่สร้างหรือเปลี่ยนข้อมูล production

## ความคลาดเคลื่อนที่ต้องจัดการ

| สัญญาเดิมใน source Phase 7 | Schema ที่ live อยู่ | ผลกระทบ |
|---|---|---|
| `product_catalog`, `retail_inventory`, `retail_orders`, `retail_transactions` | ไม่พบใน `public` | runtime ที่อิงชื่อเหล่านี้ไม่สามารถทำ transaction จริงบน project ปัจจุบัน |
| `retail_create_pos_sale`, `retail_upsert_store_product`, `retail_record_inventory_movement` | ต้องตรวจ function signature กับ schema live ก่อนทำ migration หรือแก้ runtime เพิ่ม | ห้ามประกาศว่า E2E ผ่าน และห้ามทำ mutation ทดลอง |
| Customer Retail / Admin Retail views | ยังไม่มี dataset Retail ใช้ร่วมกัน | ตรวจได้เพียง route, session gate และ static contract |

## Retail RPC ที่ยืนยันแล้ว

RPC ที่ live แล้วรองรับ flow ตามบทบาทโดยทั้งหมดเป็น `authenticated`-only และไม่เปิด `anon`: `retail_list_store_products`, `retail_create_pos_sale`, `retail_upsert_store_product`, `retail_record_inventory_movement`, `retail_list_sales`, `retail_list_customer_stores`, `retail_list_customer_products`, `retail_create_customer_delivery_order`, และชุด `retail_admin_*` สำหรับ Admin

ความหมายเชิงสถาปัตยกรรมคือ POS มี RPC สำหรับขาย, catalog และสต๊อกจริงอยู่แล้ว ขณะที่ runtime ที่เผยแพร่เรียก endpoint กลุ่ม `retail_*` เดียวกัน จึงต้องตรวจ signature, return field และ RLS ของการอ่านรายละเอียดขาย/ประวัติสต๊อกให้ครบก่อนจึงจะยืนยันความเข้ากันได้ ไม่ควรสรุปจากชื่อ migration เก่าเพียงอย่างเดียว

การตรวจ RLS แบบ read-only ยืนยันว่า `retail_pos_sales`, `retail_pos_sale_items` และ `retail_inventory_movements` มี policy `SELECT` สำหรับ role `authenticated` ในชื่อ `*_read_owner_or_admin` แล้ว ดังนั้น query ประวัติและรายละเอียดใน runtime สามารถทำงานได้ภายใต้ session ของเจ้าของร้านหรือ Admin โดยไม่ต้องผ่อนสิทธิ์หรือใช้ credential พิเศษ

การตรวจ signature ของ RPC live ยืนยันว่า runtime POS ที่เผยแพร่ใช้ชื่อ endpoint และ field หลักตรงกับ backend แล้ว: `retail_list_store_products` คืน `id`, `name`, `sku`, `price`, `unit_name`, `image_url`, `category_name`, `available_quantity`; `retail_create_pos_sale` รับ `p_payment_method`, `p_lines`, `p_idempotency_key`; และ `retail_record_inventory_movement` รับ `p_store_product_id`, `p_movement_type`, `p_quantity`, `p_reason` ส่วนหน้า Sales ใช้การอ่าน `retail_pos_sales` โดยตรงเฉพาะฟิลด์ `id`, `sale_number`, `payment_method`, `grand_total`, `created_at` ซึ่ง RLS อนุญาตแก่ `authenticated` แล้ว ดังนั้น **ไม่ต้องแก้ runtime หรือ deploy migration เพิ่ม** สำหรับความคลาดเคลื่อนนี้

> เพื่อคงกฎ **no fake data** และไม่เขียนข้อมูล production เพื่อการทดสอบ งาน Phase 8 จะเป็น schema-contract/cross-app verification แบบ read-only และจะไม่ส่งคำสั่งขาย, สร้างสินค้า หรือปรับสต๊อกจนกว่าจะมีข้อมูลจริงที่ผู้ใช้อนุญาตให้ใช้ หรือมี staging project ที่ได้รับอนุมัติ

## แหล่งตรวจสอบ

- Supabase project: `abtsctwfkgzciseppach` (สถานะ `ACTIVE_HEALTHY`)
- Supabase `list_tables` แบบ `public`, read-only, เมื่อ 2026-08-19
- Supabase `execute_sql` audit ของ `public.retail_*` functions, read-only, เมื่อ 2026-08-19
