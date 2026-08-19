# เอกสารส่งมอบ — AP Retail POS

**ผู้จัดทำ:** Manus AI  
**สถานะเอกสาร:** ส่งมอบหลัง Phase 6–8  
**ขอบเขต:** AP Retail POS web MPA, Admin Retail Management, Android WebView shell และการตรวจข้ามระบบแบบ read-only

## บทสรุปผู้บริหาร

AP Retail POS ได้เผยแพร่บน GitHub Pages และมี Android WebView shell แยก repository/แพ็กเกจสำหรับใช้งานกับเว็บ POS โดยเฉพาะ ระบบ POS ใช้ Supabase กลางเป็นแหล่งข้อมูลเดียวสำหรับสินค้า สต๊อก การขาย และ audit trail ไม่มีการรวม repository เข้ากับ Customer, Admin, Merchant หรือ Rider และไม่มีการเปลี่ยนหน้าตาเดิมของแอปเหล่านั้นเกินความจำเป็น [1] [2]

ในรอบงานนี้ ได้เพิ่มหน้า **Admin Retail Management** เพื่อให้ Admin ดูสินค้า เพิ่ม/แก้ไขรายการ และปรับสต๊อกได้ภายใต้ session ที่มีสิทธิ์ รวมทั้งทำให้ POS รองรับการขายแบบ idempotent, การอัปโหลดรูปสินค้าจากกล้องหรือคลังภาพ, ประวัติการเคลื่อนไหวสต๊อก และการดูยอดขาย/รายละเอียดใบเสร็จจากข้อมูลที่ระบบคืนจริง การตรวจ production ดำเนินการในโหมด read-only จึงไม่สร้าง order, sale, inventory movement หรือรูปภาพทดสอบปะปนกับข้อมูลธุรกิจ

> **สถานะพร้อมใช้งาน:** เว็บและ route ที่เผยแพร่ผ่านการตรวจ deployment, runtime contract, session gate และ route ข้ามแอปแล้ว ส่วนการยืนยัน mutation แบบธุรกรรมจริงต้องทำบน staging หรือด้วยรายการจริงที่ได้รับอนุญาตเป็นลายลักษณ์อักษร

## จุดเข้าถึงระบบ

| พื้นที่ | URL / รหัสระบุ | สถานะที่ตรวจ |
|---|---|---|
| AP Retail POS Web | [GitHub Pages](https://apirak272543-ship-it.github.io/ap-retail-pos/) | เผยแพร่แล้ว; POS route และ runtime asset ตอบ `200` |
| หน้า POS | [pos.html](https://apirak272543-ship-it.github.io/ap-retail-pos/pos.html) | ต้องผ่าน session gate ก่อนดึง/แสดงข้อมูลจริง |
| Customer Retail | [retail.html](https://apirak272543-ship-it.github.io/Apservice-/customer/retail.html) | เผยแพร่แล้ว; guest เห็น login gate และไม่มี catalog จำลอง |
| Admin Retail Management | [admin-retail.html](https://apirak272543-ship-it.github.io/Apservicebeta/admin/admin-retail.html) | เผยแพร่แล้ว; ไม่มี session จะส่งต่อไป Admin login |
| Source repository | [apirak272543-ship-it/ap-retail-pos](https://github.com/apirak272543-ship-it/ap-retail-pos) | `main` เป็น source สำหรับ GitHub Pages |
| Android package | `com.apservice.retailpos` | shell พร้อม build, ยังไม่มี APK/AAB ที่สร้างจริง |

## ความสามารถที่ส่งมอบ

| พื้นที่ | ความสามารถ | เงื่อนไขด้านข้อมูลและความปลอดภัย |
|---|---|---|
| POS Register | ค้นหา/เลือกสินค้า, ตะกร้า, สรุปรายการ, ชำระเงิน และป้องกันคำสั่งขายซ้ำด้วย idempotency key | Runtime ส่งเฉพาะ product ID/quantity/payment method ไปยัง Retail RPC; server เป็นผู้ตรวจ stock และบันทึกยอด |
| Catalog | เพิ่ม/แก้ไขสินค้า, SKU, ราคา, หน่วย, หมวด และรูปสินค้า | ใช้เฉพาะ camera/gallery; อัด JPEG quality `0.82`, ด้านยาวไม่เกิน `1200px`; ไม่มี URL input |
| Inventory | รับสินค้า, ปรับ, เสียหาย, สูญหาย, คืนสินค้า พร้อมเหตุผล และดู movement history | mutation ผ่าน RPC; history อ่านจากข้อมูลที่ RLS อนุญาต; ไม่มี history จำลอง |
| Sales | ดูรายการขาย, กรองข้อมูล และเปิดรายละเอียดใบเสร็จ | แสดงยอดเมื่อ server คืนค่าจริงเท่านั้น; หากไม่พร้อมจะแสดงสถานะไม่พร้อม แทนค่า `0` สมมติ |
| Admin Retail | ดูสินค้า, บันทึกสินค้า และปรับสต๊อกแบบแยกหน้า additive | ยังคง Admin session/RPC gate และใช้ media helper กลางตาม Golden Rule |
| Android shell | WebView เฉพาะ host ของ POS และ Supabase กลาง, loading/retry/external-link handling | ไม่มี credential ฝังใน APK และ URL policy ถูกตรวจด้วย contract test |

## ผลการตรวจสอบ

### Contracts และ deployment

| หมวดการตรวจ | ผล | รายละเอียด |
|---|---|---|
| POS runtime contract | ผ่าน | ตรวจ POS sale, catalog upload, inventory history, sales detail และ live-RPC alignment |
| Admin Retail contract | ผ่าน | ตรวจ route, Admin session gate, Retail RPC wrapper และ Golden Rule media profile |
| Live Supabase audit | ผ่านแบบ read-only | ตรวจ Retail RPC signature และ authenticated read policy ที่ POS ใช้จริง |
| GitHub Pages | ผ่าน | route และ asset สำคัญของ Customer, Admin, Merchant, Rider และ AP Retail POS ตอบใช้งานได้ |
| Browser runtime | ผ่านภายใต้ guest state | Customer/Admin/POS session gate ทำงาน และ console ของ route ที่ตรวจไม่พบ error ก่อน login gate |
| Android shell | ผ่านระดับ source contract | TypeScript และ shell contract ผ่านตามหลักฐานก่อนหน้า; ยังไม่ได้ส่ง EAS build |

การตรวจ live-schema พบความคลาดเคลื่อนระหว่าง assumptions จาก migration เก่ากับสิ่งที่ deploy อยู่ในฐานข้อมูลในช่วงแรก จึงได้ตรวจ signature และ RLS กับ Supabase จริงซ้ำ ก่อนยืนยันว่า endpoint/fields ที่ runtime ปัจจุบันใช้สอดคล้องกับ backend แล้ว จึง **ไม่ต้องสร้าง schema ซ้ำ ไม่ต้องเปิดสิทธิ์ anon และไม่ต้องแก้ runtime เพื่อคาดเดา schema**

## กฎที่คงไว้

| กฎ | สถานะการปฏิบัติ |
|---|---|
| แยก 5 repositories | คงอยู่; AP Retail POS อยู่ repository ของตนเอง |
| Additive-only | หน้า Admin Retail, runtime support, stylesheet และเอกสารถูกเพิ่มโดยไม่ลบ feature เดิม |
| No fake data | ไม่มี catalog, คะแนน, stock หรือยอดการเงินจำลองในสถานะไม่มีข้อมูล |
| Image Golden Rule | camera/gallery only; JPEG quality `0.82`; max `1200px`; ไม่มี URL input |
| Authenticated Retail RPC | ไม่เปิด Retail RPC ให้ `anon`; runtime ใช้ session ที่ได้รับสิทธิ์ |
| WebView–APK consistency | POS shell อ่าน GitHub Pages URL เดิม จึงรับ web updates โดยไม่ต้องแก้ native shell หาก host/URL policy ไม่เปลี่ยน |

## ขั้นตอนทดสอบ mutation อย่างปลอดภัย

การทดสอบต่อไปนี้ยังไม่ถูกสั่งรันกับ production เพราะจะเขียนข้อมูลจริง จำเป็นต้องเลือกแนวทางหนึ่งก่อนดำเนินการ

| ทางเลือก | เงื่อนไขก่อนเริ่ม | ชุดทดสอบที่อนุญาต | เกณฑ์ผ่าน |
|---|---|---|---|
| **Staging Supabase** — แนะนำ | มี project staging ที่ใช้ schema/RLS/storage policy เท่ากับ production และใช้ test accounts | Customer reserve → create order → confirm/release; POS sale → stock movement → audit; Admin visibility | จำนวน stock, order/sale state และ audit event ตรงกันทุกจุด |
| **Production ที่ควบคุมได้** | ผู้ดูแลระบุ store/product จริง, จำนวนทดสอบต่ำ, ผู้รับผิดชอบ และแผน compensating action | 1 sale และ/หรือ 1 customer order ที่มี reference ID เก็บไว้ครบ | ตรวจ stock delta, sale/order status, Admin visibility แล้วดำเนินการย้อนรายการตามขั้นตอนอนุมัติ |

ก่อนทำ mutation ควรยืนยันบัญชีทดสอบและ store scope; ห้ามใช้ service-role key ใน browser; ห้ามลบข้อมูลเพื่อย้อนผลโดยตรง และต้องเก็บ transaction/order reference IDs ไว้ใน test log สำหรับตรวจสอบย้อนหลัง

## Android APK: สถานะและขั้นตอนต่อไป

Android shell อยู่ใน `android-shell/` ของ repository และตั้งค่า Expo package เป็น `com.apservice.retailpos` แล้ว การเปลี่ยน web ในอนาคตจะสะท้อนใน shell เพราะ WebView โหลดหน้า GitHub Pages เดิม ดังนั้นปกติไม่ต้องแก้/สร้าง APK ใหม่ ยกเว้นกรณีเปลี่ยน host, URL policy, native permission, app icon หรือ native behavior [3]

ข้อจำกัดปัจจุบันคือ EAS cloud-build quota ไม่พร้อมใช้งานจนถึง **1 กันยายน 2026** ตามบันทึกใน repository จึงยังไม่มี APK/AAB ที่สร้างและติดตั้งจริง เมื่อ quota พร้อม ให้ติดตั้ง dependencies ใน `android-shell/`, รัน `pnpm check` และ `pnpm test` ก่อน แล้วจึง build profile ที่เหมาะสมตาม `eas.json`: `preview` สำหรับ APK ทดสอบติดตั้ง และ `production` สำหรับ AAB

## เอกสารอ้างอิงภายใน repository

| เอกสาร | บทบาท |
|---|---|
| `PHASE-7-IMPACT-ANALYSIS.md` | Audit/impact analysis ก่อนพัฒนา POS รอบล่าสุด |
| `PHASE-7-DEPLOYMENT-VERIFICATION.md` | หลักฐาน regression และ deployment ของ Phase 7 |
| `PHASE-8-LIVE-SCHEMA-AUDIT.md` | รายละเอียด live RPC/RLS audit แบบ read-only |
| `PHASE-8-E2E-VERIFICATION.md` | ผลตรวจ routes, session gates และข้อจำกัด end-to-end mutation |
| `DEPLOYMENT-NOTES.md` | ค่า repository, Pages และ Android shell baseline |

## References

[1] [AP Retail POS — GitHub Pages](https://apirak272543-ship-it.github.io/ap-retail-pos/)  
[2] [AP Retail POS — Source repository](https://github.com/apirak272543-ship-it/ap-retail-pos)  
[3] [Android shell source directory](https://github.com/apirak272543-ship-it/ap-retail-pos/tree/main/android-shell)
