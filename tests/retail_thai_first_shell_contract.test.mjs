import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
assert.match(page, /<title>AP Retail POS \| ระบบขายหน้าร้าน<\/title>/, 'Retail POS page title must include a Thai-first product description');
assert.match(page, /aria-label="เข้าสู่ระบบ AP Retail POS"/, 'Retail POS sign-in shell must retain a Thai accessibility label');
assert.match(page, /aria-label="อีเมล"/, 'Retail POS sign-in email input must retain a Thai accessibility label');
assert.doesNotMatch(page, /auth-intro/, 'Retail POS sign-in shell must not show a system instruction');
assert.doesNotMatch(page, /auth-footnote/, 'Retail POS sign-in shell must not show an access instruction');
console.log('retail thai-first shell contract: PASS');
