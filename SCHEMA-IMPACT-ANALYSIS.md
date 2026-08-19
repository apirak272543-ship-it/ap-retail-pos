# AP Retail POS — Schema Impact Analysis

## ขอบเขตการเปลี่ยนแปลง

Migration `20260819_001_retail_pos_foundation.sql` เพิ่มชุดตาราง Retail ใหม่โดย **ไม่เปลี่ยน ไม่ลบ และไม่ย้าย** ตารางเดิมของ AP Service. โครงสร้างแยกข้อมูล catalog ส่วนกลาง, ราคาต่อสาขา, ยอดคงเหลือ, movement แบบ append-only, POS sale และ metadata ของ retail delivery เพื่อป้องกันการปะปนกับ `menu_items` และ food-order workflow เดิม.

| ความสามารถ | ตารางใหม่ | ตารางเดิมที่เชื่อมต่อ | ผลกระทบต่อแอปเดิม |
|---|---|---|---|
| Global catalog | `retail_products`, `retail_product_identifiers` | `auth.users` | ไม่มีการแก้ menu เดิม |
| สินค้าและสต๊อกร้าน | `retail_store_products`, `retail_inventory_balances`, `retail_inventory_movements` | `stores` | Merchant/Rider เดิมไม่ถูกเปลี่ยน runtime |
| การขายหน้าร้าน | `retail_pos_sales`, `retail_pos_sale_items` | `stores`, `auth.users` | ไม่มีการแก้ `delivery_orders` |
| คำสั่งซื้อจัดส่งทั่วไป | `retail_delivery_orders`, `retail_delivery_order_items` | `delivery_orders`, `stores`, `auth.users` | เพิ่ม relation ใหม่เท่านั้น; Customer patch จะสร้าง flow นี้ใน Phase 5 |

## ผลการตรวจ dependency ก่อนสร้าง

ฐานข้อมูลกลางคือ project `abtsctwfkgzciseppach` (Apservice) และอยู่ในสถานะใช้งาน. ตาราง `stores` ใช้ primary key ชนิด `text`, `delivery_orders.id` ใช้ `text`, ส่วนผู้ใช้ใช้ `auth.users.id` ชนิด `uuid`; migration จึงกำหนด foreign key ตามชนิดข้อมูลจริง. สิทธิ์เดิมใช้ helper `private.has_role(...)` และ `private.owns_store(...)` แบบ `SECURITY DEFINER`; migration reuse helper ดังกล่าวแทนการสร้าง role system ซ้ำ.

ไม่มี RPC ที่มีชื่อขึ้นต้น `retail_` ก่อน migration จึงไม่มีความเสี่ยงทับชื่อฟังก์ชันเดิม. Post-migration security audit พบว่า default privilege ของ project ให้ `anon` เรียกฟังก์ชันโดยตรง จึงเพิ่ม migration `20260819_002_restrict_retail_rpcs.sql` เพื่อถอน `EXECUTE` จาก `anon` แบบ explicit และคงสิทธิ์ไว้เฉพาะ `authenticated`. `catalog-media` เป็น bucket สาธารณะที่กำหนดรับ JPEG/PNG/WebP และมี policy สำหรับ `store_owner` ใน path `merchant/{auth.uid()}/...`; UI Phase 7 จะอัปโหลดเฉพาะภาพที่บีบแล้วไปยัง path นี้ และส่ง URL ที่ได้จากระบบเข้าสู่ RPC เท่านั้น. จะไม่มีช่องให้กรอก URL เอง.

## การควบคุมความเสี่ยง

| ความเสี่ยง | มาตรการใน migration | วิธีทดสอบหลัง apply |
|---|---|---|
| สาขาอื่นเห็นหรือแก้ stock/sales | RLS บังคับ owner/admin และ RPC หา store จาก session | ทดสอบเรียก RPC ด้วยบัญชี store owner ที่ต่างกัน |
| UI ส่งราคา/stock ปลอม | RPC คำนวณราคาจาก `retail_store_products`, lock balance และตรวจ stock จริง | ทดสอบ payload ราคาแฝงและจำนวนเกิน stock |
| ตัด stock ซ้ำเมื่อ retry | `idempotency_key` unique ต่อ store และ RPC คืน receipt เดิม | เรียก sale RPC ซ้ำด้วย key เดิม |
| แก้ประวัติหรือ movement ย้อนหลัง | ไม่มี direct-write policy สำหรับ sales/items/movements | ตรวจ policy และทดสอบ direct insert/update ด้วย client role |
| กระทบ food workflow เดิม | ไม่แตะ `menu_items` และไม่แก้ `delivery_orders` | regression read/write ของ order เดิมใน Phase 8 |

## ความเข้ากันได้ WebView–APK

การเปลี่ยนระยะนี้เป็น **backend additive**. APK ทั้ง Apadmin, AP Store, AP Rider และ AP Retail POS ไม่ต้อง rebuild เพราะไม่มี native configuration, permission หรือ WebView URL ที่เปลี่ยน. AP Retail POS WebView shell จะอ่าน web runtime เดียวกับเว็บไซต์ที่เผยแพร่ และ UI จะเริ่มเรียก RPC ใหม่เมื่อ Phase 7 ผ่านการทดสอบเท่านั้น.
