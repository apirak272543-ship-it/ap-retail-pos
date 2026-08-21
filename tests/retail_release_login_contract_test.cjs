const assert = require('assert');
const fs = require('fs');
const path = require('path');

const app = fs.readFileSync(path.join(__dirname, '../shared/retail-app.js'), 'utf8');

assert.ok(app.includes('กรุณากรอกอีเมลและรหัสผ่านให้ครบ'), 'Retail POS Login ต้องตรวจข้อมูลก่อน sign-in');
assert.ok(app.includes('อีเมลหรือรหัสผ่านไม่ถูกต้อง กรุณาตรวจสอบแล้วลองใหม่'), 'Retail POS Login ต้อง map credential error เป็นภาษาไทย');
assert.ok(app.includes('เข้าสู่ระบบ Retail POS ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'), 'Retail POS Login ต้องมีข้อความ fallback ปลอดภัย');
assert.ok(!app.includes("showError(form, error.message)"), 'Retail POS Login ต้องไม่แสดง raw provider error');

console.log('Retail POS release-login contract: PASS');
