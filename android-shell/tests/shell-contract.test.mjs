import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

async function read(relativePath) {
  return readFile(new URL(relativePath, root), "utf8");
}

test("Android shell targets the dedicated GitHub Pages POS URL", async () => {
  const app = await read("App.tsx");
  assert.match(app, /https:\/\/apirak272543-ship-it\.github\.io\/ap-retail-pos\//);
  assert.match(app, /onShouldStartLoadWithRequest/);
  assert.match(app, /apirak272543-ship-it\.github\.io/);
});

test("Expo configuration keeps the retail POS identity and Android package", async () => {
  const config = JSON.parse(await read("app.json"));
  assert.equal(config.expo.name, "AP Retail POS");
  assert.equal(config.expo.android.package, "com.apservice.retailpos");
  assert.equal(config.expo.orientation, "portrait");
});

test("EAS profiles include an installable internal Android build and production bundle", async () => {
  const eas = JSON.parse(await read("eas.json"));
  assert.equal(eas.build.preview.android.buildType, "apk");
  assert.equal(eas.build.production.android.buildType, "app-bundle");
});
