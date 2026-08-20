(() => {
  'use strict';
  if (document.body?.dataset?.page !== 'pos') return;
  const config = window.AP_RETAIL_CONFIG;
  const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]));
  const client = () => {
    if (!config?.supabaseUrl || !config?.supabasePublishableKey || !window.supabase) throw new Error('ไม่พบการตั้งค่าระบบสแกนบาร์โค้ด');
    return window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, { auth: { persistSession: true, autoRefreshToken: true } });
  };
  const mount = () => {
    const search = document.getElementById('product-search');
    if (!search || document.getElementById('retail-barcode-lookup')) return;
    const wrap = document.createElement('div'); wrap.id = 'retail-barcode-lookup'; wrap.style.cssText = 'display:flex;gap:8px;align-items:center;margin:0 0 10px';
    wrap.innerHTML = '<label class="search-field" style="flex:1"><span aria-hidden="true">▥</span><input data-barcode-input inputmode="numeric" autocomplete="off" placeholder="สแกนหรือกรอกรหัสบาร์โค้ด / SKU แล้วกด Enter"></label><span data-barcode-status class="form-message" aria-live="polite"></span>';
    search.closest('.catalog-pane')?.insertBefore(wrap, search.closest('.search-field'));
    const input = wrap.querySelector('[data-barcode-input]'), status = wrap.querySelector('[data-barcode-status]');
    input.addEventListener('keydown', async event => {
      if (event.key !== 'Enter') return; event.preventDefault();
      const identifier = input.value.trim(); if (!identifier) return;
      input.disabled = true; status.textContent = 'กำลังตรวจรหัสในสาขา…';
      try {
        const { data, error } = await client().rpc('retail_find_store_product_by_identifier', { p_identifier: identifier });
        if (error) throw error;
        const item = Array.isArray(data) ? data[0] : null;
        if (!item) throw new Error('ไม่พบรหัสนี้ในสินค้าที่พร้อมขายของสาขา');
        if (Number(item.available_quantity) <= 0) throw new Error(`สินค้า “${item.name}” ไม่มีสต๊อกพร้อมขาย`);
        const addButton = document.querySelector(`[data-add-product="${CSS.escape(item.id)}"]`);
        if (!addButton) throw new Error('พบสินค้าแต่หน้าขายยังโหลดรายการไม่พร้อม กรุณารอสักครู่แล้วสแกนซ้ำ');
        addButton.click(); input.value = ''; status.textContent = `เพิ่ม “${escapeHtml(item.name)}” ลงตะกร้าแล้ว`;
      } catch (error) { status.textContent = error.message || 'ค้นหาบาร์โค้ดไม่สำเร็จ'; }
      finally { input.disabled = false; input.focus(); }
    });
  };
  const observer = new MutationObserver(mount); observer.observe(document.body, { childList: true, subtree: true }); mount(); addEventListener('pagehide', () => observer.disconnect(), { once: true });
})();
