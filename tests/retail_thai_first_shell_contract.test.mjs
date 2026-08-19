import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
assert.match(page, /<title>AP Retail POS \| ระบบขายหน้าร้าน<\/title>/, 'Retail POS page title must include a Thai-first product description');
assert.match(page, /<h1 id="signin-title">ระบบขายหน้าร้าน<\/h1>/, 'Retail POS sign-in heading must be Thai-first');
assert.match(page, /ผู้ดูแลระบบ AP Service อนุมัติแล้ว/, 'Retail POS access instruction must be Thai-first');
assert.doesNotMatch(page, />Retail POS<\//, 'Retail POS must not expose an untranslated generic sign-in heading');
console.log('retail thai-first shell contract: PASS');
