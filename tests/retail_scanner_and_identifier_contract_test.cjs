const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const assert = (condition, message) => { if (!condition) throw new Error(message); };

const migration = read('supabase/migrations/20260821_008_retail_identifier_admin.sql');
const admin = read('../Apservicebeta/admin/admin-retail-patch.js');
const pos = read('pos.html');
const lookup = read('shared/retail-barcode-lookup.js');
const camera = read('shared/retail-camera-scanner.js');

assert(/retail_admin_list_product_identifiers/.test(migration), 'Admin identifier list RPC missing');
assert(/retail_admin_upsert_product_identifier/.test(migration), 'Admin identifier upsert RPC missing');
assert(/retail_admin_delete_product_identifier/.test(migration), 'Admin identifier delete RPC missing');
assert(/private\.has_role\('admin'\)/.test(migration), 'identifier RPCs must enforce Admin role');
assert(/revoke all on function public\.retail_admin_upsert_product_identifier/.test(migration), 'identifier upsert must revoke public access');
assert(/grant execute on function public\.retail_admin_upsert_product_identifier.*authenticated/.test(migration), 'identifier upsert must grant authenticated execution only');
assert(/data-retail-action="identifiers"/.test(admin), 'Admin identifier action missing');
assert(/retail_admin_list_product_identifiers/.test(admin) && /retail_admin_upsert_product_identifier/.test(admin), 'Admin UI does not call identifier RPCs');
assert(/retail-camera-scanner\.js\?v=retail-camera-v1/.test(pos), 'POS camera scanner asset missing');
assert(/retail-barcode-lookup\.js\?v=retail-barcode-v2/.test(pos), 'POS barcode lookup asset version missing');
assert(/retail_find_store_product_by_identifier/.test(lookup), 'Existing authoritative lookup RPC must remain in scanner path');
assert(/getUserMedia/.test(camera) && /BarcodeDetector/.test(camera), 'Camera scanner must use browser camera and BarcodeDetector');
assert(/data-camera-manual/.test(camera) && /กรอกรหัส/.test(camera), 'Camera scanner must preserve manual fallback');
console.log('retail scanner and identifier contract: PASS');
