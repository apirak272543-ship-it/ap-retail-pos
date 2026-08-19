import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("Retail POS confirms before signing out", async () => {
  const source = await readFile(new URL("../shared/retail-app.js", import.meta.url), "utf8");
  assert.match(source, /function confirmSignOut\(\)/);
  assert.match(source, /ยืนยันการออกจากระบบ/);
  assert.match(source, /if \(!await confirmSignOut\(\)\) return;/);
  assert.match(source, /state\.client\.auth\.signOut\(\)/);
});
