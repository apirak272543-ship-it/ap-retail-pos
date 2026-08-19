# Phase 8 — Cross-App End-to-End Verification

## ขอบเขตและวิธีการ

การตรวจครั้งนี้เป็น **read-only verification** กับ Supabase production และ GitHub Pages ที่เผยแพร่จริง โดยตั้งใจไม่สร้าง order, sale, stock movement, product หรือการจองสต๊อกเพื่อไม่ให้เกิดข้อมูลทดสอบในระบบ production และไม่ละเมิดกฎ no-fake-data

## หลักฐานจาก Supabase

| จุดตรวจ | ผล | หลักฐาน |
|---|---|---|
| Retail RPC live | ผ่าน | Signature ของ endpoint ที่ POS runtime เรียกตรงกับ backend ที่ deploy: `retail_list_store_products`, `retail_create_pos_sale`, `retail_upsert_store_product`, `retail_record_inventory_movement` |
| POS sales/inventory reads | ผ่าน | ตาราง `retail_pos_sales`, `retail_pos_sale_items`, `retail_inventory_movements` มี authenticated SELECT policy สำหรับ owner/admin |
| การเขียนข้อมูล | ไม่ดำเนินการโดยเจตนา | ไม่มี API call ที่สร้าง sale/order, เปลี่ยน stock หรือ upload สื่อระหว่าง audit |

## หลักฐานจาก GitHub Pages

| เว็บไซต์/asset | URL ที่ตรวจ | HTTP | ผล |
|---|---|---:|---|
| Customer Retail | `/Apservice-/customer/retail.html` | 200 | ผ่าน; guest เห็น login gate ที่อธิบายว่าสต๊อก/ราคามาจากร้านจริง |
| Admin Retail Management | `/Apservicebeta/admin/admin-retail.html` | 200 | ผ่าน; route เปลี่ยนเข้าสู่ Admin login เมื่อไม่มี session |
| Merchant | `/ap-store-mobile/merchant/` | 200 | ผ่าน |
| Rider | `/ap-rider-mobile/rider/` | 200 | ผ่าน |
| AP Retail POS | `/ap-retail-pos/pos.html` | 200 | ผ่าน; route ถูก session-gate ก่อน rendering ข้อมูล |
| AP Retail POS runtime | `/ap-retail-pos/shared/retail-app.js` | 200 | ผ่าน |

## Runtime/browser verification

| หน้าจอ | ผลที่ตรวจได้โดยไม่ใช้บัญชีผู้ใช้ | ผล |
|---|---|---|
| Customer Retail | แสดง login state ที่ชัดเจน ไม่แสดงสินค้าหรือราคา/ยอดขายจำลอง | ผ่าน |
| Admin Retail | บังคับเข้าหน้า Admin login อย่างถูกต้องเมื่อไม่มีสิทธิ์ | ผ่าน |
| Browser console ทั้งสอง route | ไม่มี console output/error ก่อน session gate | ผ่าน |

## ข้อจำกัดที่บันทึกไว้

> ยังไม่สามารถยืนยัน mutation แบบ end-to-end ของเส้นทาง **Customer reserve → order → stock confirmation → Admin visibility** และ **POS sale → inventory movement → audit trail** ได้โดยไม่ใช้ข้อมูลจริงหรือ staging environment เพราะการยิง mutation เพื่อทดสอบจะสร้างผลกระทบถาวรต่อ production data

ก่อนทดสอบ mutation จริง ควรเลือกหนึ่งในสองทางเลือกต่อไปนี้: ใช้ **staging Supabase project** ที่มี schema เดียวกัน หรือระบุ store/product จริงที่อนุญาตและกำหนดแผนย้อนรายการ (compensating action) อย่างชัดเจน หลังจากนั้นจึงจะทดสอบธุรกรรมได้ครบทั้งเส้นทางโดยไม่ปนข้อมูลทดสอบกับข้อมูลธุรกิจ

## ข้อสรุป

การตรวจ Phase 8 ยืนยันได้ว่า routes, session gates, Retail RPC contracts และสิทธิ์อ่านที่ runtime พึ่งพาอยู่มีความสอดคล้องกันบน production ที่เผยแพร่จริง โดยไม่พบข้อผิดพลาดจาก browser console ในเส้นทางที่ตรวจ และไม่มีการเปลี่ยน source ของ Customer, Merchant หรือ Rider ระหว่าง Phase 7–8
