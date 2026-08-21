(() => {
  'use strict';
  if (document.body?.dataset?.page !== 'pos') return;
  const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]));
  const supportedFormats = ['qr_code', 'ean_13', 'ean_8', 'code_128', 'code_39', 'code_93', 'codabar', 'itf', 'upc_a', 'upc_e', 'data_matrix', 'aztec', 'pdf417'];
  let state = null;
  const close = () => { state?.stream?.getTracks().forEach(track => track.stop()); state?.dialog?.remove(); state = null; };
  const showStatus = text => { if (state?.status) state.status.textContent = text; if (state?.dialog) state.dialog.querySelector('[data-camera-status]').textContent = text; };
  const mountFallback = (dialog, message) => { const manual = document.createElement('div'); manual.className = 'retail-camera-fallback'; manual.innerHTML = `<p>${escapeHtml(message)}</p><label class="search-field"><span aria-hidden="true">▥</span><input data-camera-manual inputmode="numeric" autocomplete="off" placeholder="กรอกรหัสแล้วกดเพิ่ม"></label><button class="button button-primary" type="button" data-camera-manual-submit>เพิ่มจากรหัส</button>`; dialog.querySelector('[data-camera-fallback]').replaceChildren(manual); manual.querySelector('[data-camera-manual-submit]').onclick = async () => { const value = manual.querySelector('[data-camera-manual]').value.trim(); if (!value) return; showStatus('กำลังตรวจรหัสในสาขา…'); try { const item = await window.APServiceRetailBarcodeLookup.lookup(value); showStatus(`เพิ่ม “${item.name}” ลงตะกร้าแล้ว`); window.setTimeout(close, 260); } catch (error) { showStatus(error.message || 'ค้นหารหัสไม่สำเร็จ'); } }; };
  const scan = async video => {
    if (!state || !('BarcodeDetector' in window)) return;
    let detector;
    try {
      const formats = typeof window.BarcodeDetector.getSupportedFormats === 'function' ? await window.BarcodeDetector.getSupportedFormats() : supportedFormats;
      detector = new window.BarcodeDetector({ formats: supportedFormats.filter(format => formats.includes(format)) });
    } catch { mountFallback(state.dialog, 'อุปกรณ์นี้ไม่รองรับการอ่าน QR/Barcode จากกล้อง ใช้ช่องกรอกรหัสด้านล่างแทน'); return; }
    const frame = async () => {
      if (!state || video.readyState < 2) { if (state) requestAnimationFrame(frame); return; }
      try {
        const detections = await detector.detect(video);
        const value = detections?.[0]?.rawValue;
        if (value) { showStatus('พบรหัสแล้ว กำลังตรวจสินค้า…'); const item = await window.APServiceRetailBarcodeLookup.lookup(value); showStatus(`เพิ่ม “${item.name}” ลงตะกร้าแล้ว`); window.setTimeout(close, 260); return; }
      } catch (error) { showStatus(error.message || 'อ่านรหัสไม่สำเร็จ ลองหันกล้องไปที่รหัสใหม่'); }
      if (state) requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  };
  const open = async ({ status } = {}) => {
    if (state) return;
    const dialog = document.createElement('dialog'); dialog.className = 'retail-camera-dialog'; dialog.innerHTML = '<div class="retail-camera-card"><div class="retail-camera-heading"><div><p class="eyebrow">CAMERA SCAN</p><h2>สแกน QR / Barcode</h2></div><button class="icon-button" type="button" data-camera-close aria-label="ปิด">×</button></div><div class="retail-camera-viewport"><video data-camera-video autoplay muted playsinline></video><span class="retail-camera-frame" aria-hidden="true"></span></div><p data-camera-status class="form-message" role="status" aria-live="polite">กำลังเปิดกล้อง…</p><div data-camera-fallback></div><button class="button button-secondary" type="button" data-camera-close>ยกเลิก</button></div>'; document.body.append(dialog); state = { dialog, status, stream: null }; dialog.querySelectorAll('[data-camera-close]').forEach(button => button.onclick = close); dialog.addEventListener('cancel', event => { event.preventDefault(); close(); }); dialog.showModal();
    if (!navigator.mediaDevices?.getUserMedia) { mountFallback(dialog, 'เบราว์เซอร์นี้ไม่เปิดกล้อง ใช้ช่องกรอกรหัสด้านล่างแทน'); return; }
    try { state.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false }); const video = dialog.querySelector('[data-camera-video]'); video.srcObject = state.stream; await video.play(); if (!('BarcodeDetector' in window)) mountFallback(dialog, 'เบราว์เซอร์นี้ไม่รองรับ BarcodeDetector ใช้ช่องกรอกรหัสด้านล่างแทน'); else scan(video); }
    catch (error) { mountFallback(dialog, error?.name === 'NotAllowedError' ? 'ไม่ได้รับอนุญาตให้ใช้กล้อง ใช้ช่องกรอกรหัสด้านล่างแทน' : 'เปิดกล้องไม่สำเร็จ ใช้ช่องกรอกรหัสด้านล่างแทน'); }
  };
  window.APServiceRetailCameraScanner = { open, close };
})();
