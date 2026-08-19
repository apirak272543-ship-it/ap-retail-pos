# Phase 7 — Deployment Verification

## การเผยแพร่

| รายการ | ผลลัพธ์ |
|---|---|
| Repository | `apirak272543-ship-it/ap-retail-pos` |
| Commit | `fddb0ae28566341e7e7fcd8f0b79957c894a8df7` |
| Workflow | GitHub Pages run `32226509843` |
| สถานะ workflow | สำเร็จ (build และ deploy สำเร็จ) |
| URL หลัก | <https://apirak272543-ship-it.github.io/ap-retail-pos/> |

## การตรวจหลังเผยแพร่

| การตรวจ | ผลลัพธ์ |
|---|---|
| `pos.html` บน GitHub Pages | redirect ไปหน้า login ตาม session gate ที่ออกแบบไว้ |
| หน้า login | แสดงเฉพาะช่องอีเมล/รหัสผ่านและข้อความสิทธิ์ร้านค้า ไม่มี catalog หรือยอดขายจำลองก่อนยืนยันตัวตน |
| Browser console ก่อน login | ไม่มีข้อความผิดพลาด |
| `runtime-contract.test.mjs` | ผ่าน 5/5: cart guard, image Golden Rule, idempotent POS sale, inventory history, sales detail |
| `schema-contract.test.mjs` | ผ่าน |
| `customer-checkout-contract.test.mjs` | ผ่าน |
| JavaScript syntax และ whitespace check | ผ่าน (`node --check`, `git diff --check`) |

## ผลกระทบ WebView และแอปอื่น

การเปลี่ยนแปลงอยู่ใน repository **AP Retail POS** เท่านั้น และยังใช้ origin, เส้นทาง GitHub Pages และหน้า login เดิม ดังนั้น Android WebView shell ของ AP Retail POS จะรับ runtime ล่าสุดจาก URL เดิมโดยไม่ต้องแก้ package หรือฝัง credential ใหม่ ส่วน Customer, Admin, Merchant และ Rider ไม่มี source file ถูกแก้ใน Phase 7; จุดเชื่อมร่วมคือ Retail schema/RPC เดิมที่ตรวจแล้วเท่านั้น

> การทดสอบการขายจริงต้องทำภายใต้ session บัญชีร้านค้าที่ได้รับสิทธิ์และมีสินค้าจริงในสาขา จึงไม่ดำเนินการสร้างข้อมูลจำลองหรือขายทดสอบในฐานข้อมูล production ระหว่างการตรวจนี้
