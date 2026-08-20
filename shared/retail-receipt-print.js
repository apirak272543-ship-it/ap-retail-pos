(() => {
  'use strict';
  if (document.body?.dataset?.page !== 'sales') return;
  let activeSaleId = '';
  const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]));
  const money = value => new Intl.NumberFormat('th-TH', { style: 'currency', currency: 'THB' }).format(Number(value) || 0);
  const getClient = () => {
    if (!window.supabase || !window.CONFIG?.supabaseUrl || !window.CONFIG?.supabasePublishableKey) throw new Error('ไม่พบการตั้งค่าการเชื่อมต่อ Retail POS');
    return window.supabase.createClient(window.CONFIG.supabaseUrl, window.CONFIG.supabasePublishableKey, { auth: { persistSession: true, autoRefreshToken: true } });
  };
  const addPrintButton = () => {
    const heading = document.querySelector('#sale-detail-dialog .dialog-heading');
    if (!heading || heading.querySelector('[data-print-receipt]')) return;
    const button = document.createElement('button');
    button.type = 'button'; button.dataset.printReceipt = 'true'; button.className = 'icon-button'; button.textContent = 'พิมพ์ใบเสร็จ'; button.setAttribute('aria-label', 'พิมพ์ใบเสร็จ');
    heading.insertBefore(button, heading.querySelector('[data-action="close-sale-detail"]'));
  };
  const printReceipt = async () => {
    if (!activeSaleId) throw new Error('ยังไม่ได้เลือกรายการขาย');
    const client = getClient();
    const [{ data: sale, error: saleError }, { data: items, error: itemError }] = await Promise.all([
      client.from('retail_pos_sales').select('sale_number,payment_method,grand_total,created_at').eq('id', activeSaleId).single(),
      client.from('retail_pos_sale_items').select('product_name_snapshot,sku_snapshot,unit_name_snapshot,unit_price,quantity,line_total').eq('sale_id', activeSaleId).order('created_at', { ascending: true }),
    ]);
    if (saleError || itemError || !sale) throw new Error(saleError?.message || itemError?.message || 'อ่านข้อมูลใบเสร็จไม่สำเร็จ');
    const receipt = window.open('', '_blank', 'noopener,noreferrer,width=420,height=680');
    if (!receipt) throw new Error('เบราว์เซอร์บล็อกหน้าพิมพ์ กรุณาอนุญาต popup แล้วลองใหม่');
    receipt.document.write(`<!doctype html><html lang="th"><head><meta charset="utf-8"><title>ใบเสร็จ ${escapeHtml(sale.sale_number)}</title><style>body{font-family:system-ui,sans-serif;margin:22px;color:#102a22}h1{font-size:18px;margin:0 0 6px}.muted{color:#52635d;font-size:12px}table{width:100%;border-collapse:collapse;margin:14px 0;font-size:13px}td{padding:7px 0;border-bottom:1px dashed #aab7b1}td:last-child{text-align:right}.total{font-weight:800;font-size:17px;text-align:right;margin-top:14px}@media print{body{margin:0}}</style></head><body><h1>AP Retail POS</h1><p class="muted">เลขที่ ${escapeHtml(sale.sale_number)}<br>${escapeHtml(new Date(sale.created_at).toLocaleString('th-TH'))}<br>ชำระ: ${escapeHtml(sale.payment_method)}</p><table><tbody>${(items || []).map(item => `<tr><td>${escapeHtml(item.product_name_snapshot)}<br><span class="muted">${escapeHtml(item.sku_snapshot || '')} · ${escapeHtml(item.quantity)} ${escapeHtml(item.unit_name_snapshot)}</span></td><td>${escapeHtml(money(item.line_total))}</td></tr>`).join('')}</tbody></table><p class="total">รวม ${escapeHtml(money(sale.grand_total))}</p><p class="muted">เอกสารอ้างอิงจากรายการขายที่ระบบยืนยันแล้ว</p><script>window.onload=()=>window.print();<\/script></body></html>`);
    receipt.document.close();
  };
  document.addEventListener('click', event => {
    const target = event.target.closest?.('[data-view-sale],[data-print-receipt]');
    if (!target) return;
    if (target.dataset.viewSale) { activeSaleId = target.dataset.viewSale; window.setTimeout(addPrintButton, 0); return; }
    if (target.dataset.printReceipt) printReceipt().catch(error => { const detail = document.getElementById('sale-detail'); if (detail) detail.insertAdjacentHTML('afterbegin', `<p class="empty-state">${escapeHtml(error.message || 'พิมพ์ใบเสร็จไม่สำเร็จ')}</p>`); });
  });
})();
