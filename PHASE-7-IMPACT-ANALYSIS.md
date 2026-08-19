# Phase 7 — AP Retail POS: Impact Analysis

## วัตถุประสงค์

เติมเฉพาะความสามารถที่ยังขาดใน **AP Retail POS** ได้แก่ การส่งคำสั่งขายอย่างปลอดภัย, การสร้าง/แก้ไข catalog, การบันทึกและดูประวัติการเคลื่อนไหวของสต๊อก, และรายงานยอดขาย/รายละเอียดใบเสร็จ โดยยึด Supabase โครงการ `abtsctwfkgzciseppach` เป็นแหล่งข้อมูลเดียว

## หลักฐานก่อนดำเนินการ

| หัวข้อ | สิ่งที่ตรวจพบ | ข้อสรุปสำหรับการพัฒนา |
|---|---|---|
| Migration จริง | มี `retail_pos_foundation`, การจำกัด RPC สำหรับ authenticated, Customer checkout และ Admin Retail Management แล้ว | ไม่ต้องสร้าง schema ซ้ำหรือเปิดสิทธิ์ `anon` |
| POS sale | `retail_create_pos_sale(p_payment_method, p_lines, p_idempotency_key)` ทำการตรวจ stock และบันทึกการขาย/สต๊อกแบบ atomic | runtime ต้องส่ง idempotency key และห้ามคำนวณยอดขายปลอมฝั่ง client |
| Catalog | `retail_upsert_store_product(p_product)` รองรับ `name`, `sku`, `price`, `unit_name`, `image_url` | runtime ปัจจุบันส่ง `image` แบบ base64 ซึ่งไม่ตรง contract; จะเปลี่ยนเป็นลำดับอัปโหลดสื่อที่ให้ URL ก่อนบันทึกสินค้า |
| Inventory | `retail_record_inventory_movement` รองรับ receipt, adjustment, damage, loss, return พร้อมเหตุผล และมี validation คงเหลือ | จะเพิ่มชนิดการเคลื่อนไหวที่ขาดและเพิ่มประวัติจากข้อมูล audit ที่ backend เปิดให้ตามสิทธิ์ |
| Sales | `retail_list_sales(p_limit)` คืนเฉพาะรายการสรุป | จะเพิ่มการกรอง/สรุปจากผลลัพธ์จริง และเพิ่ม detail เฉพาะเมื่อ query ที่มีสิทธิ์และ contract รองรับ โดยไม่สร้างตัวเลขสมมติ |
| Session | Retail RPC ทุกตัวเป็น authenticated-only | คง session gate และไม่ใส่ service credential ในเว็บหรือ Android shell |

## ขอบเขตการเปลี่ยนแปลง

| พื้นที่ | การเปลี่ยนแปลงที่อนุญาต | สิ่งที่ไม่ทำ |
|---|---|---|
| `pos.html` และ `shared/retail-app.js` | เพิ่ม guard การส่งซ้ำ, idempotency, สถานะผลลัพธ์ และ lookup ที่อ้างอิง stock จริง | ไม่แก้ราคา/คงเหลือฝั่ง client และไม่ทำ checkout แบบจำลอง |
| `catalog.html` และ runtime | เพิ่ม field ที่ RPC รองรับ และอัปโหลดรูปจาก camera/gallery เท่านั้น โดยบีบอัด JPEG 0.82, ด้านยาวไม่เกิน 1200px | ไม่มี URL image input และไม่แตะ catalog ของ Customer/Merchant เดิม |
| `inventory.html` และ runtime | เพิ่ม movement types, empty state และประวัติจริงตามสิทธิ์ | ไม่ลด stock โดยข้าม RPC และไม่แสดง history จำลอง |
| `sales.html` และ runtime | เพิ่ม filter/summary/detail view เฉพาะข้อมูลที่ server ส่งได้จริง | ไม่คำนวณยอดรายรับหรือยอดขายจำลอง |
| Android WebView shell | ไม่ต้องแก้ source shell หาก URL และ navigation ยังอยู่ภายใต้ GitHub Pages เดิม | ไม่ embed credential, ไม่สร้าง APK ใหม่ใน sandbox |

## ผลกระทบข้ามแอป

| แอป | ระดับผลกระทบ | เหตุผลและมาตรการ |
|---|---|---|
| Customer | ต่ำ | ใช้ Retail tables/stock ร่วมกัน จึงทดสอบ reservation/availability ภายหลัง; ไม่มีการแก้ source Customer ใน Phase 7 |
| Admin | ต่ำ | ใช้ Admin Retail management RPC คนละหน้าที่; ไม่แก้ UI หรือ runtime ของ Admin |
| Merchant | ต่ำ | AP Retail POS ใช้สิทธิ์เจ้าของร้านผ่าน session เดิม; ไม่แก้ source Merchant |
| Rider | ไม่มีโดยตรง | ไม่มี route หรือ UI Rider ถูกแก้; จะตรวจ regression หลังเผยแพร่ |
| AP Retail POS WebView APK | ต้องยืนยัน | WebView อ่าน GitHub Pages เดิม จึงต้องตรวจ route และ asset ภายหลัง deployment |

## เกณฑ์ยอมรับ

- ทุก mutation ใช้ authenticated RPC, ตรวจ error และไม่ส่งข้อมูลการเงิน/stock ที่สร้างขึ้นเอง
- ทุก upload ยอมรับเฉพาะรูปจาก camera/gallery, JPEG quality `0.82`, ด้านยาวไม่เกิน `1200px`
- ถ้าไม่มีข้อมูล ใช้ loading/empty state ที่ชัดเจน
- ทดสอบ contract, syntax, deployment route และ cross-app regression ก่อนสรุป Phase 7
