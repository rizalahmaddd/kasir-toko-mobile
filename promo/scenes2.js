/* Features 5–12, outro, and build entrypoint. */

function appBar(title, actions = [], back = true) {
  return `<div class="appbar">${back ? `<span class="back">${ic('arrow-left', 22)}</span>` : ''}<span class="sp">${title}</span>${actions.map((a) => `<span class="iconbtn">${ic(a, 20)}</span>`).join('')}</div>`;
}
function thumb(p, s = 44) {
  return `<div style="width:${s}px;height:${s}px;border-radius:8px;background:${p.bg};display:grid;place-items:center;font-size:${s * 0.55}px;font-family:'Noto Color Emoji';flex:none">${p.emo}</div>`;
}

/* =========================== F5: HOLD =========================== */
function f5() {
  const s = S(4);
  movePhone(PH, s - 0.2, 0.6);
  const items = ['kopi', 'roti', 'teh', 'mie'];
  const scr = addScreen(el(`<div class="screen app" id="s5"><div class="safe">${appBar('Keranjang')}
    <div class="row" style="padding:8px 16px 12px;gap:10px"><div style="width:36px;height:36px;border-radius:10px;background:var(--slate800);display:grid;place-items:center">${ic('user', 18, '#94A3B8')}</div>
      <div class="sp"><div style="font-size:13px;font-weight:700">Pelanggan umum</div><div class="muted" style="font-size:11px">Pilih member atau kasbon</div></div>${ic('chevron-right', 18, '#94A3B8')}<span class="iconbtn">${ic('trash-2', 18)}</span></div>
    <div style="height:1px;background:var(--slate800)"></div>
    ${items.map((k) => `<div class="row" style="padding:10px 14px;gap:10px;border-bottom:1px solid rgba(30,41,59,.6)">${thumb(P[k])}<div class="sp"><div style="font-size:13.5px;font-weight:600;line-height:1.25">${P[k].name}</div><div class="muted" style="font-size:12px;margin-top:3px">${rp(P[k].price)} / pcs</div></div>
      <div class="col" style="align-items:flex-end;gap:6px"><div class="tab" style="font-size:14.5px;font-weight:700">${rp(P[k].price)}</div>
      <div class="row" style="border-radius:8px;border:1px solid rgba(30,41,59,.9);background:rgba(30,41,59,.5)"><span style="padding:4px 7px">${ic('trash-2', 14)}</span><b style="font-size:14px;padding:0 6px">1</b><span style="padding:4px 7px">${ic('plus', 14)}</span></div></div></div>`).join('')}
    <div style="position:absolute;left:0;right:0;bottom:0;padding:14px 16px 16px;background:var(--slate900);border-top:1px solid var(--slate800);border-radius:16px 16px 0 0">
      <div class="row muted" style="font-size:13px;justify-content:space-between"><span>Subtotal</span><span class="tab" style="color:#F1F5F9;font-weight:600">Rp43.000</span></div>
      <div class="row muted" style="font-size:13px;justify-content:space-between;margin-top:6px"><span>Diskon</span><span style="color:var(--emerald500);font-weight:600">Atur Diskon &gt;</span></div>
      <div style="height:1px;background:var(--slate800);margin:10px 0"></div>
      <div class="row"><div class="sp"><div style="font-size:15px;font-weight:600">Total</div><div class="muted" style="font-size:11px">4 barang</div></div><div class="tab" style="font-size:22px;font-weight:800;color:var(--emerald500)">Rp43.000</div></div>
      <div class="row" style="gap:8px;margin-top:12px"><div class="btn out holdbtn" style="width:104px;height:52px">${ic('pause', 18)}Tunda</div><div class="btn fill sp" style="height:52px;font-weight:700;font-size:16px">${ic('check-check', 20, '#fff')}Bayar Rp43.000</div></div></div>
    </div></div>`));
  showScreen(scr, s - 0.05);
  hideScreen($('#s4'), s + 0.3);
  tapEl(scr, $('.holdbtn', scr), s + 0.45);

  const scrim = el(`<div class="scrim"></div>`);
  const dlg = el(`<div class="dialog" style="transform:none;padding:24px">
    <div style="font-size:24px;font-weight:400;margin-bottom:18px">Tunda transaksi</div>
    <div class="field focus"><span class="flabel">Nama penanda (opsional)</span><span class="tv" style="font-size:16px"></span><span class="caret"></span></div>
    <div class="row" style="justify-content:flex-end;gap:8px;margin-top:22px"><div class="btn txt" style="padding:0 12px">Batal</div><div class="btn fill okb" style="padding:0 22px;height:40px;border-radius:20px">Tunda</div></div></div>`);
  scr.append(scrim, dlg);
  centerDialog(dlg);
  gsap.set(dlg, { autoAlpha: 0 });
  tl.to(scrim, { opacity: 1, duration: 0.2 }, s + 0.58);
  popIn(dlg, s + 0.6, 0.35, { scale: 0.9 });
  typeText($('.tv', dlg), 'Bu Rina', s + 0.85, 13, $('.caret', dlg));
  typeSfx(s + 0.85, 'Bu Rina', 13);
  tapEl(scr, $('.okb', dlg), s + 1.5);

  // back on the catalog, held badge ticks up
  const cat = addScreen(posScreen('s5b', ['kopi', 'roti', 'teh', 'mie', 'air', 'telur'], { held: 1, cart: false }));
  showScreen(cat, s + 1.62, 0.25);
  hideScreen(scr, s + 1.9);
  const badge = $('.heldbadge', cat);
  steps(badge, [[0, '1'], [s + 1.95, '2']]);
  tl.fromTo(badge, { scale: 1 }, { scale: 1.8, duration: 0.15, yoyo: true, repeat: 1, ease: 'power2.out' }, s + 1.95);
  const clock = offsetIn($('.clockbtn', cat), cat);
  const fly = el(`<div style="position:absolute;left:60px;top:560px;width:240px;height:64px;border-radius:14px;background:linear-gradient(135deg,#059669,#047857);z-index:44;display:flex;align-items:center;gap:10px;padding:0 14px;color:#fff;font-weight:700;font-size:14px;box-shadow:0 8px 20px rgba(0,0,0,.5)">${ic('shopping-bag', 20, '#fff')}Bu Rina · Rp43.000</div>`);
  cat.append(fly);
  gsap.set(fly, { autoAlpha: 0 });
  tl.fromTo(fly, { autoAlpha: 1, x: 0, y: 0, scale: 1 }, { x: clock.cx - 180, y: clock.cy - 592, scale: 0.08, duration: 0.42, ease: 'power3.in' }, s + 1.58).set(fly, { autoAlpha: 0 }, s + 2.0);
  sfx(s + 1.6, 'swoosh-up');
  const sn = el(snack('Transaksi ditunda. Buka lagi dari tombol jam di atas katalog.'));
  cat.append(sn);
  popIn(sn, s + 2.0); popOut(sn, s + 2.55);

  // queue keeps moving
  const q = ov(el(`<div class="ov glass" style="padding:16px 16px;border-radius:24px;width:196px">
      <div style="font-size:22px;font-weight:700;color:#94A3B8;margin-bottom:12px">Antrean</div>
      ${['Bu Rina', 'Pak Joko', 'Mbak Ayu', 'Dimas'].map((n, i) => `<div class="qp" style="display:flex;align-items:center;gap:12px;height:64px"><div style="width:48px;height:48px;border-radius:50%;background:${['#F59E0B', '#0EA5E9', '#8B5CF6', '#F43F5E'][i]};display:grid;place-items:center;font-weight:800;font-size:22px">${n[n.indexOf(' ') + 1]}</div><span style="font-size:21px;font-weight:600;white-space:nowrap">${n}</span></div>`).join('')}</div>`), 876, 1060);
  ovIn(q, s + 0.3, { x: 80, scale: 0.8 });
  const qp = $$('.qp', q);
  tl.to(qp[0], { x: -260, autoAlpha: 0, duration: 0.4, ease: 'power3.in' }, s + 1.7)
    .to(qp.slice(1), { y: -64, duration: 0.4, ease: 'power3.out' }, s + 1.95);
  ovOut(q, s + FLEN - 0.2);

  // open held orders
  tapEl(cat, $('.clockbtn', cat), s + 2.55);
  const scrim2 = el(`<div class="scrim"></div>`);
  const sheet = el(`<div class="sheet" style="top:330px">${sheetHeader('Transaksi Tertunda', '2 pesanan tersimpan')}<div style="padding:4px 16px 20px;display:flex;flex-direction:column;gap:8px">
    ${[[12, 'Bu Rina', 43000, 4, 'Baru saja · 09:41', '1x Kopi Susu Gula Aren, 1x Roti Tawar Gandum, 1x Teh Botol Sosro 450ml, ...'], [11, 'Meja 3', 36500, 3, '12 mnt lalu · 09:29', '2x Indomie Goreng Original, 1x Telur Ayam Negeri, 1x Air Mineral 600ml']]
      .map(([id, n, v, c, tm, pv], i) => `<div class="card2 ho${i}" style="border-radius:12px;padding:11px 14px">
        <div class="row" style="gap:8px"><span class="pill" style="background:rgba(120,53,15,.4);color:#D97706;padding:2px 6px">${ic('pause', 10, '#D97706', 3)}#${id}</span><b class="sp" style="font-size:14px">${n}</b><b class="tab" style="font-size:15px;font-weight:800;color:#059669">${rp(v)}</b></div>
        <div class="row" style="margin-top:5px;gap:8px"><div class="sp" style="min-width:0"><div class="row" style="gap:4px;font-size:12px;color:#CBD5E1;font-weight:600">${ic('shopping-bag', 12, '#94A3B8')}${c} item<span style="color:#64748B;margin:0 4px">·</span>${ic('clock', 12, '#94A3B8')}<span style="font-size:11px;color:#94A3B8;font-weight:400">${tm}</span></div>
        <div style="font-size:11px;color:#94A3B8;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${pv}</div></div>
        ${ic('trash-2', 16, '#DC2626')}<div class="btn" style="height:30px;padding:0 10px;border-radius:8px;background:#059669;color:#fff;font-size:12px;gap:4px">${ic('play', 12, '#fff')}Lanjut</div></div></div>`).join('')}</div></div>`);
  cat.append(scrim2, sheet);
  gsap.set(sheet, { yPercent: 100 });
  tl.to(scrim2, { opacity: 1, duration: 0.25 }, s + 2.62).to(sheet, { yPercent: 0, duration: 0.42, ease: 'power3.out' }, s + 2.62);
  tl.fromTo($('.ho0', sheet), { boxShadow: '0 0 0 0 rgba(16,185,129,0)' }, { boxShadow: '0 0 0 3px rgba(16,185,129,.8)', duration: 0.3, yoyo: true, repeat: 1 }, s + 3.1);
  sfx(s + 2.62, 'sheet');
}

/* =========================== F6: KASBON =========================== */
function f6() {
  const s = S(5);
  const rows = [
    ['Pak Budi Santoso', 'INV/20260915/0032', '15 Sep 2026', 19, 350000, 500000, 150000],
    ['Bu Sari Wulandari', 'INV/20260928/0071', '28 Sep 2026', 6, 225000, 225000, 0],
    ['Mas Andi Pratama', 'INV/20261003/0080', '3 Okt 2026', 1, 700000, 900000, 200000],
  ];
  const scr = addScreen(el(`<div class="screen app" id="s6"><div class="safe">${appBar('Piutang (kasbon)', ['search'])}
    <div style="margin:0 16px 8px;padding:14px 16px;border-radius:14px;background:rgba(245,158,11,.1);border:1px solid rgba(245,158,11,.3)" class="row">
      <div class="sp"><div class="muted" style="font-size:12px;font-weight:600">Total belum lunas</div><div class="tab totout" style="font-size:24px;font-weight:800;color:#F59E0B;margin-top:2px">Rp1.275.000</div></div>
      <div style="width:44px;height:44px;border-radius:12px;background:rgba(245,158,11,.15);display:grid;place-items:center">${ic('hand-coins', 22, '#F59E0B')}</div></div>
    ${rows.map(([n, inv, d, age, due, tot, paid], i) => `<div class="card2 rc${i}" style="margin:5px 16px;padding:14px;position:relative">
      <div class="row" style="gap:10px"><div style="padding:8px;border-radius:8px;background:rgba(245,158,11,.12)">${ic('user', 16, '#F59E0B')}</div>
        <div class="sp" style="min-width:0"><div style="font-size:15px;font-weight:700">${n}</div><div class="muted" style="font-size:12px;margin-top:2px;white-space:nowrap"><b style="font-weight:600">${inv.slice(4)}</b> · ${d.slice(0, -5)}</div></div>
        <span class="pill" style="font-weight:600;${age > 14 ? 'background:rgba(244,63,94,.1);color:#F43F5E' : 'background:#334155;color:#94A3B8'}">${age} hari</span></div>
      <div class="row" style="margin-top:12px;padding:10px;border-radius:10px;background:var(--slate900);gap:6px">
        <div class="sp"><div class="muted" style="font-size:11px">Sisa Kasbon</div><div class="tab due" style="font-size:15px;font-weight:800;color:#F59E0B;margin-top:2px">${rp(due)}</div></div>
        <div style="text-align:right;font-size:10.5px;white-space:nowrap" class="muted"><div>Total ${rp(tot)}</div><div class="paid" style="margin-top:2px">Dibayar ${rp(paid)}</div></div>
        <span class="iconbtn" style="width:26px">${ic('history', 15)}</span>
        <div class="btn tonal paybtn" style="height:32px;padding:0 10px;font-size:12px;font-weight:700;gap:6px">${ic('hand-coins', 14)}Bayar</div></div>
      <div class="flashc" style="position:absolute;inset:-1px;border-radius:14px;border:2px solid #34D399;background:rgba(16,185,129,.08);opacity:0"></div></div>`).join('')}
    </div></div>`));
  showScreen(scr, s - 0.05);
  hideScreen($('#s5b'), s + 0.3);
  tl.fromTo($$('.card2', scr), { autoAlpha: 0, y: 30 }, { autoAlpha: 1, y: 0, duration: 0.4, stagger: 0.07, ease: 'power3.out' }, s + 0.05);

  // heads-up reminder
  const hu = el(`<div style="position:absolute;left:10px;right:10px;top:36px;z-index:46;border-radius:22px;background:#1E293B;padding:12px 14px;box-shadow:0 10px 30px rgba(0,0,0,.6)">
    <div class="row" style="gap:6px;font-size:11px;color:#94A3B8"><img src="icon.png" style="width:16px;height:16px;border-radius:4px">Kasir Toko · sekarang</div>
    <div style="font-size:14px;font-weight:700;margin-top:6px">⏰ Kasbon jatuh tempo hari ini</div>
    <div style="font-size:13px;color:#CBD5E1;margin-top:2px">Pak Budi Santoso · sisa Rp350.000</div></div>`);
  scr.append(hu);
  gsap.set(hu, { autoAlpha: 0 });
  tl.fromTo(hu, { autoAlpha: 1, yPercent: -140 }, { yPercent: 0, duration: 0.4, ease: 'back.out(1.5)' }, s + 0.45).to(hu, { yPercent: -140, duration: 0.3, ease: 'power2.in' }, s + 1.45);
  sfx(s + 0.45, 'notif');
  const bell = ov(el(`<div class="ov" style="width:132px;height:132px;border-radius:50%;background:#F59E0B;display:grid;place-items:center;box-shadow:0 0 0 12px rgba(245,158,11,.22),0 20px 40px rgba(0,0,0,.5)">${ic('bell-ring', 70, '#fff', 2.2)}</div>`), 880, 560);
  ovIn(bell, s + 0.45, { scale: 0.2 });
  tl.fromTo($('svg', bell), { rotate: -18 }, { rotate: 18, duration: 0.09, repeat: 9, yoyo: true, ease: 'sine.inOut' }, s + 0.55);
  ovOut(bell, s + 1.5);

  // record a partial payment
  const c0 = $('.rc0', scr);
  tapEl(scr, $('.paybtn', c0), s + 1.55);
  const scrim = el(`<div class="scrim"></div>`);
  const sheet = el(`<div class="sheet">${sheetHeader('Catat pelunasan', 'INV/20260915/0032 · Pak Budi Santoso · sisa Rp350.000')}<div class="sheet-b">
    <div style="display:flex;gap:8px;margin-bottom:14px"><span class="achip">Lunas</span><span class="achip">Setengah</span></div>
    ${moneyField('Nominal dibayar')}
    <div class="mchips">${[['banknote', 'Tunai'], ['qr-code', 'QRIS'], ['landmark', 'Transfer']].map(([i, l], k) => `<div class="mchip">${k === 0 ? '<div class="onbg" style="opacity:1"></div>' : ''}${ic(i, 16, k === 0 ? '#10B981' : '#F1F5F9')}<b>${l}</b></div>`).join('')}</div>
    <div class="muted" style="font-size:12px;margin-top:12px">Pelunasan tunai masuk ke rekap laci shift yang sedang buka.</div>
    <div class="btn fill savebtn" style="margin-top:16px">Simpan Pelunasan</div></div></div>`);
  scr.append(scrim, sheet);
  gsap.set(sheet, { yPercent: 100 });
  tl.to(scrim, { opacity: 1, duration: 0.2 }, s + 1.65).to(sheet, { yPercent: 0, duration: 0.38, ease: 'power3.out' }, s + 1.65);
  sfx(s + 1.65, 'sheet');
  const fv = $('.fv', sheet);
  const seq = ['1', '15', '150', '1.500', '15.000', '150.000'];
  steps(fv, [[0, '']].concat(seq.map((v, i) => [s + 1.95 + i * 0.07, v])));
  typeSfx(s + 1.95, '150000', 1 / 0.07);
  tapEl(scr, $('.savebtn', sheet), s + 2.5);
  tl.to(sheet, { yPercent: 100, duration: 0.3, ease: 'power2.in' }, s + 2.6).to(scrim, { opacity: 0, duration: 0.25 }, s + 2.62);
  counter($('.due', c0), s + 2.8, 0.55, 350000, 200000);
  counter($('.paid', c0), s + 2.8, 0.55, 150000, 300000, (v) => `Dibayar ${rp(v)}`);
  counter($('.totout', scr), s + 2.8, 0.55, 1275000, 1125000);
  tl.fromTo($('.flashc', c0), { opacity: 1 }, { opacity: 0, duration: 0.9, immediateRender: false }, s + 2.8);
  sfx(s + 2.8, 'success');
  const sn = el(snack('Pelunasan dicatat. Sisa Rp200.000.'));
  sn.style.bottom = '16px';
  scr.append(sn);
  popIn(sn, s + 2.9);
  const cb = ovC(toast('history', 'Cicilan ke-2 tercatat otomatis', '#059669'), 1700);
  ovIn(cb, s + 2.95); ovOut(cb, s + FLEN - 0.15);
}

/* =========================== F7: SHIFT =========================== */
function f7() {
  const s = S(6);
  const scr = addScreen(el(`<div class="screen app" id="s7"><div class="safe">${appBar('Shift saya', ['history', 'printer', 'refresh-cw'])}<div style="position:absolute;left:0;right:0;top:56px;bottom:0;overflow:hidden"><div class="scroll" style="padding:4px 16px">
    <div class="panel" style="border-radius:18px;padding:18px">
      <div class="row"><span class="pill" style="background:#1E293B;border:1px solid #334155;color:#E2E8F0;font-size:13px;padding:4px 10px">${ic('hash', 13, '#94A3B8')}24</span><span class="sp"></span><span class="pill" style="background:rgba(52,211,153,.14);color:#34D399">Shift Aktif</span></div>
      <div class="muted" style="font-size:13px;margin-top:14px">Uang di laci seharusnya</div>
      <div class="tab" style="font-size:34px;font-weight:800;letter-spacing:-.2px">Rp1.250.000</div>
      <div class="row" style="margin-top:12px;padding:10px 6px;border-radius:12px;background:rgba(30,41,59,.6);border:1px solid #1E293B">
        ${[['Modal Awal', 'Rp300.000', '#E2E8F0'], ['Kas Masuk', 'Rp50.000', '#10B981'], ['Kas Keluar', 'Rp25.000', '#F43F5E']].map(([l, v, c], i) => `${i ? '<div style="width:1px;height:26px;background:#334155"></div>' : ''}<div class="sp" style="text-align:center"><div class="muted" style="font-size:10.5px">${l}</div><div class="tab" style="font-size:12px;font-weight:700;color:${c};margin-top:2px">${v}</div></div>`).join('')}</div>
      <div class="row" style="gap:6px;margin-top:12px;font-size:12.5px;color:#CBD5E1">${ic('user', 14, '#64748B')}Kasir: Rina</div>
      <div class="row muted" style="gap:6px;margin-top:6px;font-size:12px">${ic('clock', 14, '#64748B')}Dibuka 04/10/2026 07:00</div></div>
    <div class="card" style="margin-top:12px;padding:14px 16px"><div style="font-size:14px;font-weight:700;margin-bottom:8px">Rekapitulasi Arus Kas</div>
      ${[['Modal awal', 'Rp300.000'], ['Penjualan tunai', 'Rp925.000'], ['Kas masuk', 'Rp50.000'], ['Kas keluar', '-Rp25.000']].map(([l, v]) => `<div class="row" style="justify-content:space-between;font-size:13px;padding:5px 0"><span class="muted">${l}</span><span class="tab" style="font-weight:600">${v}</span></div>`).join('')}</div>
    <div class="card" style="margin-top:12px;padding:16px"><div style="font-size:15px;font-weight:700">Tutup Shift Kasir</div><div class="muted" style="font-size:12.5px;margin-top:4px;line-height:1.4">Pastikan semua pesanan telah selesai dan hitung uang tunai di laci kasir.</div>
      <div class="btn danger closebtn" style="margin-top:12px">${ic('lock-keyhole', 18, '#fff')}Tutup Shift</div></div></div></div></div></div>`));
  showScreen(scr, s - 0.05);
  hideScreen($('#s6'), s + 0.3);
  const scroll = $('.scroll', scr);
  tl.to(scroll, { y: -170, duration: 0.45, ease: 'power2.inOut' }, s + 0.4);
  tapEl(scr, $('.closebtn', scr), s + 0.95, 'tap', -170);

  const scrim = el(`<div class="scrim"></div>`);
  const sheet = el(`<div class="sheet">${sheetHeader('Tutup shift 24', 'Seharusnya ada Rp1.250.000 di laci.')}<div class="sheet-b">
    <div class="cf">${moneyField('Uang fisik yang dihitung')}</div>
    <div class="diff" style="margin-top:8px;font-weight:600;font-size:14px;min-height:20px"></div>
    <div class="field" style="margin-top:12px;color:#94A3B8;font-size:15px">Catatan (opsional)</div>
    <div class="btn danger" style="margin-top:12px">Tutup Shift</div></div></div>`);
  scr.append(scrim, sheet);
  gsap.set(sheet, { yPercent: 100 });
  tl.to(scrim, { opacity: 1, duration: 0.2 }, s + 1.05).to(sheet, { yPercent: 0, duration: 0.38, ease: 'power3.out' }, s + 1.05);
  sfx(s + 1.05, 'sheet');
  // type 1.200.000 → difference shows live → fix it to 1.250.000
  const seq = [];
  let t = s + 1.35;
  for (const d of ['1', '12', '120', '1200', '12000', '120000', '1200000']) { seq.push([t, d]); sfx(t, 'key'); t += 0.06; }
  t = s + 2.45;
  for (const d of ['120000', '12000', '1200', '120', '12']) { seq.push([t, d]); sfx(t, 'key'); t += 0.045; }
  for (const d of ['125', '1250', '12500', '125000', '1250000']) { seq.push([t, d]); sfx(t, 'key'); t += 0.05; }
  const fv = $('.fv', sheet), diff = $('.diff', sheet);
  at((tt) => {
    let v = '';
    for (const [a, d] of seq) if (tt >= a) v = d;
    fv.textContent = v ? dots(+v) : '';
    if (!v) { diff.textContent = ''; return; }
    const dd = +v - 1250000;
    diff.textContent = dd === 0 ? 'Pas, tidak ada selisih.' : `Selisih ${dd > 0 ? '+' : ''}${rp(dd)}`;
    diff.style.color = dd === 0 ? '#34D399' : '#F59E0B';
  });
  tl.fromTo($('.cf', sheet), { x: -10 }, { x: 0, duration: 0.5, ease: 'elastic.out(1.4,0.25)' }, s + 1.8);
  sfx(s + 1.8, 'error');
  const warn = ovC(toast('triangle-alert', 'Kurang Rp50.000 — langsung ketahuan!', '#D97706'), 1690);
  ovIn(warn, s + 1.85); ovOut(warn, s + 2.4);
  tl.to('#blobWarn', { opacity: 0.25, duration: 0.3 }, s + 1.8).to('#blobWarn', { opacity: 0, duration: 0.4 }, s + 2.5);
  const ok = ovC(toast('circle-check', 'Uang laci cocok, aman!', '#059669'), 1690);
  ovIn(ok, s + 3.0); ovOut(ok, s + FLEN - 0.12);
  sfx(s + 3.0, 'success');
}

/* =========================== F8: PROFIT =========================== */
function f8() {
  const s = S(7);
  const bars = [62, 48, 70, 55, 82, 74, 100];
  const scr = addScreen(el(`<div class="screen app" id="s8"><div class="safe">
    <div class="row" style="height:60px;padding:0 8px 0 16px;gap:10px"><div style="width:38px;height:38px;border-radius:50%;background:linear-gradient(135deg,#10B981,#0D9488);display:grid;place-items:center;font-weight:800">H</div>
      <div class="sp"><div style="font-size:15px;font-weight:700">Selamat siang, Hendra</div><div class="muted" style="font-size:11.5px">Toko Berkah Jaya · Pemilik</div></div>
      <span class="iconbtn">${ic('search', 20)}</span><span class="iconbtn">${ic('bell', 20)}<span class="badge">3</span></span></div>
    <div style="padding:4px 16px;display:flex;flex-direction:column;gap:12px">
      <div class="card row" style="padding:12px 14px;gap:10px"><div style="width:10px;height:10px;border-radius:50%;background:#10B981"></div><div class="sp"><div style="font-size:12px;font-weight:700;color:#E2E8F0">Shift Kasir Aktif <span class="muted" style="font-weight:500;font-size:11px">#24</span></div><div class="muted" style="font-size:11px;margin-top:2px">Kas awal: Rp300.000 · Est. laci: Rp1.250.000</div></div><span class="pill" style="background:#1E293B;color:#CBD5E1;font-weight:600">Kelola Kas${ic('chevron-right', 14, '#94A3B8')}</span></div>
      <div class="panel hero" style="border-radius:18px;padding:18px">
        <div class="row" style="gap:10px"><div style="padding:7px;border-radius:10px;background:rgba(16,185,129,.2)">${ic('chart-column-increasing', 16, '#10B981')}</div><div class="sp"><div style="font-size:13px;font-weight:600;color:#CBD5E1">Penjualan Hari Ini</div><div class="muted" style="font-size:11px"><span class="cnt">0</span> transaksi dicatat</div></div><span class="pill" style="background:#1E293B;color:#CBD5E1;font-weight:600;border-radius:20px;padding:5px 10px">Laporan${ic('arrow-up-right', 13, '#94A3B8')}</span></div>
        <div class="tab rev" style="font-size:34px;font-weight:800;margin-top:14px;color:#fff">Rp0</div>
        <div class="row" style="gap:8px;margin-top:8px"><span class="pill" style="background:rgba(16,185,129,.2);color:#34D399">${ic('trending-up', 13, '#34D399')}+12.4%</span><span class="muted" style="font-size:11px">vs kemarin (Rp4.315.000)</span></div>
        <div class="row" style="margin-top:16px;padding:10px 12px;border-radius:12px;background:rgba(2,6,23,.6);border:1px solid #1E293B">
          <div class="sp" style="padding:0 4px"><div class="muted" style="font-size:10px">Transaksi</div><div class="tab cnt2" style="font-size:13px;font-weight:700">0</div><div style="font-size:9px;color:#64748B">Selesai</div></div>
          <div style="width:1px;height:28px;background:#1E293B"></div>
          <div class="sp" style="padding:0 4px"><div class="muted" style="font-size:10px">Rata-rata/Struk</div><div class="tab avg" style="font-size:13px;font-weight:700">Rp0</div><div style="font-size:9px;color:#64748B">Nilai belanja</div></div>
          <div style="width:1px;height:28px;background:#1E293B"></div>
          <div class="sp lk" style="padding:0 4px;position:relative"><div class="muted" style="font-size:10px">Laba Kotor</div><div class="tab prof" style="font-size:13px;font-weight:700;color:#34D399">Rp0</div><div style="font-size:9px;color:#64748B">30% margin</div>
            <div class="ring" style="position:absolute;inset:-8px -6px;border-radius:10px;border:2px solid #34D399;box-shadow:0 0 16px rgba(52,211,153,.6);opacity:0"></div></div></div></div>
      <div class="card" style="padding:16px;border-radius:16px"><div class="row"><div class="sp"><div style="font-size:14px;font-weight:700">Tren Omzet 7 Hari</div><div class="muted" style="font-size:11px">Total 7 hari: Rp29.640.000</div></div><span class="muted" style="font-size:12px;font-weight:600">Detail</span></div>
        <div class="row" style="align-items:flex-end;gap:10px;height:110px;margin-top:14px">${bars.map((h, i) => `<div class="sp col" style="align-items:center;gap:6px;height:100%;justify-content:flex-end"><div class="bar" style="width:100%;height:${h}%;border-radius:6px 6px 3px 3px;background:${i === 6 ? 'linear-gradient(180deg,#34D399,#059669)' : '#1E293B'};transform-origin:50% 100%"></div><span class="muted" style="font-size:10px">${['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][i]}</span></div>`).join('')}</div></div>
    </div></div>${navBar(0)}</div>`));
  showScreen(scr, s - 0.05);
  hideScreen($('#s7'), s + 0.3);
  counter($('.rev', scr), s + 0.2, 1.3, 0, 4850000, rp, 'power3.out');
  counter($('.cnt', scr), s + 0.2, 1.3, 0, 86, String, 'power3.out');
  counter($('.cnt2', scr), s + 0.2, 1.3, 0, 86, String, 'power3.out');
  counter($('.avg', scr), s + 0.3, 1.2, 0, 56395, rp, 'power3.out');
  counter($('.prof', scr), s + 0.4, 1.3, 0, 1455000, rp, 'power3.out');
  sfx(s + 0.2, 'count', { dur: 1.2 });
  tl.fromTo($$('.bar', scr), { scaleY: 0 }, { scaleY: 1, duration: 0.5, stagger: 0.06, ease: 'back.out(1.6)' }, s + 0.6);
  tl.fromTo($('.ring', scr), { opacity: 0, scale: 1.3 }, { opacity: 1, scale: 1, duration: 0.35, ease: 'back.out(2)' }, s + 1.6)
    .to($('.ring', scr), { opacity: 0.4, duration: 0.3, repeat: 3, yoyo: true }, s + 2.0);

  const eqc = ovC(el(`<div class="ov glass" style="width:900px;padding:26px 34px;border-radius:30px">
    <div class="row" style="justify-content:space-between;font-size:32px;font-weight:600;color:#CBD5E1"><span class="row" style="gap:14px">${ic('banknote', 34, '#94A3B8')}Omzet</span><b class="tab e1" style="color:#fff">Rp0</b></div>
    <div class="row er2" style="justify-content:space-between;font-size:32px;font-weight:600;color:#CBD5E1;margin-top:14px"><span class="row" style="gap:14px">${ic('package', 34, '#F43F5E')}Modal barang (HPP)</span><b class="tab e2" style="color:#FB7185">−Rp0</b></div>
    <div class="er3"><div style="height:2px;background:rgba(148,163,184,.3);margin:18px 0"></div>
    <div class="row" style="justify-content:space-between;font-size:40px;font-weight:800"><span class="row" style="gap:14px">${ic('sparkles', 40, '#34D399')}Untung</span><b class="tab e3 hl" style="font-size:52px">Rp0</b></div></div></div>`), 1470);
  ovIn(eqc, s + 1.75, { y: 80, scale: 0.9 });
  counter($('.e1', eqc), s + 1.85, 0.45, 0, 4850000);
  tl.fromTo($('.er2', eqc), { autoAlpha: 0, x: -30 }, { autoAlpha: 1, x: 0, duration: 0.3 }, s + 2.2);
  counter($('.e2', eqc), s + 2.2, 0.45, 0, 3395000, (v) => '−' + rp(v));
  tl.fromTo($('.er3', eqc), { autoAlpha: 0, y: 20 }, { autoAlpha: 1, y: 0, duration: 0.3 }, s + 2.6);
  counter($('.e3', eqc), s + 2.65, 0.5, 0, 1455000);
  tl.fromTo($('.e3', eqc), { scale: 1 }, { scale: 1.15, duration: 0.15, yoyo: true, repeat: 1, transformOrigin: '100% 50%' }, s + 3.15);
  sfx(s + 3.15, 'cash');
  ovOut(eqc, s + FLEN - 0.15);
}

/* =========================== F9: PRESETS =========================== */
function f9() {
  const s = S(8);
  const presets = [
    ['shopping-basket', 'Toko Kelontong', 'Sembako, minuman, rokok, dan kebutuhan harian.'],
    ['coffee', 'Kafe & Kedai Kopi', 'Menu kopi, minuman, dan camilan siap jual.'],
    ['shirt', 'Toko Pakaian', 'Kaos, kemeja, celana, dan aksesoris.'],
    ['utensils-crossed', 'Rumah Makan', 'Makanan, minuman, dan paket menu.'],
    ['hammer', 'Bengkel & Sparepart', 'Oli, sparepart, dan jasa servis.'],
    ['pill', 'Apotek', 'Obat bebas, vitamin, dan alat kesehatan.'],
    ['smartphone', 'Konter HP', 'Pulsa, aksesoris, dan servis ringan.'],
    ['croissant', 'Toko Roti & Kue', 'Roti, kue basah, dan pesanan.'],
  ];
  const scr = addScreen(el(`<div class="screen app" id="s9"><div class="safe">${appBar('Pilih Jenis Toko', [], false).replace('</span></div>', '</span><span style="color:#10B981;font-size:14px;font-weight:600;padding-right:8px">Keluar</span></div>')}
    <div style="position:absolute;left:0;right:0;top:56px;bottom:0;overflow:hidden"><div class="scroll" style="padding:0 16px"><div style="font-size:18px;font-weight:700;letter-spacing:-.2px">Pilih jenis usaha Anda untuk memulai</div>
    <div class="muted" style="font-size:13px;line-height:1.4;margin-top:6px">Kategori, produk contoh, dan pengaturan kasir akan disesuaikan dengan jenis toko Anda.</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:16px">${presets.map(([i, l, d], k) => `<div class="card ps" style="height:150px;padding:14px;position:relative">
      <div class="psel" style="position:absolute;inset:-1px;border-radius:14px;border:1.8px solid #10B981;background:rgba(16,185,129,.06);opacity:0"></div>
      <div style="position:relative;width:40px;height:40px;border-radius:10px;background:#1E293B;display:grid;place-items:center">${ic(i, 22, '#10B981')}</div>
      <div style="position:relative;font-size:14px;font-weight:700;margin-top:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${l}</div>
      <div class="muted" style="position:relative;font-size:11.5px;line-height:1.3;margin-top:4px">${d}</div></div>`).join('')}</div></div></div></div></div>`));
  showScreen(scr, s - 0.05);
  hideScreen($('#s8'), s + 0.3);
  const cards = $$('.ps', scr);
  tl.fromTo(cards, { autoAlpha: 0, scale: 0.85, y: 20 }, { autoAlpha: 1, scale: 1, y: 0, duration: 0.4, stagger: 0.05, ease: 'back.out(1.6)' }, s + 0.05);
  const picks = [[0, s + 0.85], [1, s + 1.25], [2, s + 1.65], [4, s + 2.3], [5, s + 2.7]];
  const scroll = $('.scroll', scr);
  tl.to(scroll, { y: -170, duration: 0.4, ease: 'power2.inOut' }, s + 1.85);
  picks.forEach(([k, t], j) => {
    tapEl(scr, $('div', cards[k]).nextElementSibling, t, 'tap', k >= 4 ? -170 : 0);
    const next = picks[j + 1] ? picks[j + 1][1] : 99;
    tl.fromTo($('.psel', cards[k]), { opacity: 0 }, { opacity: 1, duration: 0.15 }, t).to($('.psel', cards[k]), { opacity: 0, duration: 0.15 }, next);
  });
  // label pill flips through the store types
  const pill = ovC(el(`<div class="ov glass" style="display:flex;align-items:center;gap:18px;padding:16px 34px 16px 16px;border-radius:999px;white-space:nowrap">
    <div style="width:64px;height:64px;border-radius:50%;background:#10B981;display:grid;place-items:center;position:relative">${picks.map(([k], j) => `<span class="pi" style="position:absolute">${ic(presets[k][0], 34, '#fff', 2.2)}</span>`).join('')}</div>
    <div style="font-size:34px;font-weight:800;position:relative;height:44px;width:380px;overflow:hidden">${picks.map(([k]) => `<div class="pl" style="position:absolute;left:0;top:0">${presets[k][1]}</div>`).join('')}</div></div>`), 1720);
  ovIn(pill, s + 0.8);
  const pis = $$('.pi', pill), pls = $$('.pl', pill);
  picks.forEach(([, t], j) => {
    const next = picks[j + 1] ? picks[j + 1][1] : 99;
    gsap.set([pis[j], pls[j]], { autoAlpha: 0 });
    tl.fromTo([pis[j], pls[j]], { autoAlpha: 0, yPercent: 80 }, { autoAlpha: 1, yPercent: 0, duration: 0.25, ease: 'power3.out' }, t)
      .to([pis[j], pls[j]], { autoAlpha: 0, yPercent: -80, duration: 0.18, ease: 'power2.in' }, next - 0.05);
  });
  ovOut(pill, s + 2.95);
  const sn = el(snack('Preset Apotek diterapkan: 6 kategori dan 30 produk contoh dibuat.', 'circle-check'));
  sn.style.bottom = '16px';
  scr.append(sn);
  popIn(sn, s + 3.05);
  sfx(s + 3.05, 'success');
}

/* =========================== F10: NEGATIVE STOCK =========================== */
function f10() {
  const s = S(9);
  const scr = addScreen(posScreen('s10', ['ksb', 'teh', 'air', 'uht', 'kopi', 'donat'], { held: 1, cat: 1 }));
  showScreen(scr, s - 0.05);
  hideScreen($('#s9'), s + 0.3);
  const cards = $$('.pcard', scr);
  tl.fromTo(cards[0], { boxShadow: '0 0 0 0 rgba(244,63,94,0)' }, { boxShadow: '0 0 0 4px rgba(244,63,94,.6)', duration: 0.3, yoyo: true, repeat: 3 }, s + 0.4);

  // supplier delivery
  const truck = ov(el(`<div class="ov" style="width:420px;height:200px">
    <div class="tk" style="position:absolute;right:0;bottom:0;font-size:170px;line-height:1;font-family:'Noto Color Emoji'">🚚</div>
    ${[0, 1, 2].map((i) => `<div class="bx" style="position:absolute;left:${20 + i * 70}px;bottom:${i === 1 ? 70 : 0}px;font-size:84px;line-height:1;font-family:'Noto Color Emoji'">📦</div>`).join('')}</div>`), 600, 1560);
  tl.set(truck, { autoAlpha: 1 }, s);
  tl.fromTo($('.tk', truck), { x: 600 }, { x: 0, duration: 0.55, ease: 'power3.out' }, s + 0.05);
  tl.fromTo($$('.bx', truck), { autoAlpha: 0, y: -160, scale: 0.4 }, { autoAlpha: 1, y: 0, scale: 1, duration: 0.45, stagger: 0.1, ease: 'bounce.out' }, s + 0.45);
  sfx(s + 0.05, 'truck'); sfx(s + 0.6, 'thud'); sfx(s + 0.75, 'thud');
  const lab = ov(toast('truck', 'Barang baru datang!', '#D97706', 'font-size:28px'), 70, 1430);
  ovIn(lab, s + 0.5);
  tl.to($('.tk', truck), { x: -1300, duration: 0.5, ease: 'power3.in' }, s + 0.95).set(truck, { autoAlpha: 0 }, s + 1.5).to($$('.bx', truck), { autoAlpha: 0, scale: 0.3, duration: 0.25, stagger: 0.05 }, s + 1.0).to(lab, { autoAlpha: 0, y: 40, duration: 0.3, ease: 'power2.in' }, s + 1.05);
  sfx(s + 0.95, 'truck');

  const times = [s + 1.0, s + 1.35, s + 1.7];
  times.forEach((t) => tapEl(scr, $('.photo', cards[0]), t));
  cardQty(cards[0], times.map((t, i) => [t, i + 1]));
  driveCartBar(scr, times.map((t, i) => [t, i + 1, (i + 1) * 12000]));
  const sn = el(snack('Stok sistem Kopi Susu Botol 250ml kosong. Tetap ditambahkan.'));
  sn.style.bottom = '160px';
  scr.append(sn);
  popIn(sn, s + 1.1); popOut(sn, s + 2.4);

  const set = ovC(el(`<div class="ov glass" style="width:940px;padding:26px 30px;border-radius:30px;display:flex;align-items:center;gap:24px">
    <div style="width:72px;height:72px;border-radius:20px;background:rgba(16,185,129,.16);display:grid;place-items:center;flex:none">${ic('package-plus', 40, '#34D399')}</div>
    <div style="flex:1"><div style="font-size:30px;font-weight:700">Bolehkan jual saat stok habis</div><div style="font-size:22px;color:#94A3B8;margin-top:6px;line-height:1.35">Barang fisik sudah ada tapi belum sempat di-input stok masuk.</div></div>
    <div class="sw" style="width:104px;height:60px;border-radius:30px;border:3px solid #475569;position:relative;flex:none"><div class="swbg" style="position:absolute;inset:-3px;border-radius:30px;background:#10B981;opacity:0"></div><div class="knob" style="position:absolute;left:10px;top:12px;width:30px;height:30px;border-radius:50%;background:#CBD5E1"></div></div></div>`), 1600);
  ovIn(set, s + 2.05, { y: 80, scale: 0.9 });
  tl.to($('.swbg', set), { opacity: 1, duration: 0.2 }, s + 2.45)
    .to($('.knob', set), { x: 44, y: -8, width: 46, height: 46, background: '#fff', duration: 0.3, ease: 'back.out(2)' }, s + 2.45);
  sfx(s + 2.45, 'toggle');
  ovOut(set, s + FLEN - 0.15);
}

/* =========================== F11: ROLES =========================== */
function f11() {
  const s = S(10);
  const pos = phonePos(330, 640, 1.45);
  movePhone(pos, s - 0.2, 0.6);
  const items = [['kopi', 2], ['mie', 3], ['roti', 1], ['telur', '0,5'], ['teh', 2]];
  const scr = addScreen(el(`<div class="screen app" id="s11"><div class="safe">${appBar('Detail transaksi', ['printer', 'message-circle'])}<div style="padding:0 16px">
    <div class="card" style="padding:16px"><div class="row"><b class="sp" style="font-size:15px">INV/20261004/0087</b><span class="pill" style="background:rgba(52,211,153,.14);color:#34D399">Selesai</span></div>
      <div class="muted" style="font-size:12px;margin-top:4px">04/10/2026 09:41 · Kasir Rina</div>
      <div class="tab" style="font-size:28px;font-weight:800;margin-top:10px">Rp87.000</div>
      <div class="row" style="gap:6px;margin-top:6px"><span class="pill" style="background:rgba(14,165,233,.14);color:#38BDF8">${ic('qr-code', 12, '#38BDF8')}QRIS</span><span class="muted" style="font-size:12px">Lunas</span></div></div>
    <div class="card" style="margin-top:12px;padding:6px 16px">${items.map(([k, q]) => `<div class="row" style="padding:9px 0;border-bottom:1px solid rgba(30,41,59,.7);gap:10px">${thumb(P[k], 36)}<div class="sp"><div style="font-size:13px;font-weight:600">${P[k].name}</div><div class="muted" style="font-size:11.5px">${q} × ${rp(P[k].price)}</div></div><b class="tab" style="font-size:13px">${rp(Math.round(parseFloat(String(q).replace(',', '.')) * P[k].price))}</b></div>`).join('')}</div>
    <div class="btn voidbtn" style="margin-top:14px;border:1px solid rgba(244,63,94,.5);color:#F43F5E">${ic('ban', 18, '#F43F5E')}Batalkan Transaksi</div></div></div></div>`));
  showScreen(scr, s - 0.05);
  hideScreen($('#s10'), s + 0.3);

  const card = ov(el(`<div class="ov glass" style="width:470px;padding:26px 28px;border-radius:30px">
    <div class="row" style="gap:16px"><div style="width:68px;height:68px;border-radius:50%;background:#F59E0B;display:grid;place-items:center;font-size:32px;font-weight:800">R</div>
      <div><div style="font-size:32px;font-weight:800">Rina</div><span class="pill" style="font-size:20px;background:rgba(245,158,11,.18);color:#FBBF24;padding:4px 12px;border-radius:10px">${ic('user-round', 18, '#FBBF24')}Kasir</span></div></div>
    <div style="height:1.5px;background:rgba(148,163,184,.2);margin:20px 0 8px"></div>
    ${[['Melayani pembayaran', 1], ['Cetak & kirim struk', 1], ['Lihat harga modal', 0], ['Lihat laporan untung', 0], ['Hapus transaksi', 0]].map(([l, okk], i) => `<div class="row pr pr${i}" style="gap:16px;height:66px;font-size:26px;font-weight:600;${okk ? '' : 'color:#94A3B8'}">
      <div style="width:46px;height:46px;border-radius:14px;display:grid;place-items:center;position:relative;background:${okk ? 'rgba(16,185,129,.18)' : 'rgba(244,63,94,.16)'}">${okk ? ic('check', 28, '#34D399', 3) : `<span class="lo" style="position:absolute">${ic('lock-open', 26, '#94A3B8', 2.4)}</span><span class="lc" style="position:absolute;opacity:0">${ic('lock', 26, '#F43F5E', 2.6)}</span>`}</div>${l}</div>`).join('')}
    <div class="row own" style="gap:10px;margin-top:14px;padding:12px 16px;border-radius:16px;background:rgba(16,185,129,.12);font-size:21px;font-weight:600;color:#6EE7B7">${ic('crown', 24, '#FBBF24')}Akses penuh hanya untuk pemilik</div></div>`), 590, 690);
  ovIn(card, s + 0.25, { x: 120, scale: 0.9 });
  [2, 3, 4].forEach((i, j) => {
    const t = s + 0.75 + j * 0.3, row = $(`.pr${i}`, card);
    tl.to($('.lo', row), { opacity: 0, duration: 0.08 }, t).fromTo($('.lc', row), { opacity: 0, scale: 1.8, rotate: -30 }, { opacity: 1, scale: 1, rotate: 0, duration: 0.35, ease: 'back.out(3)' }, t)
      .to(row, { color: '#F1F5F9', duration: 0.2 }, t);
    sfx(t, 'lock');
  });
  tl.fromTo($('.own', card), { autoAlpha: 0, y: 14 }, { autoAlpha: 1, y: 0, duration: 0.3 }, s + 2.5);

  tapEl(scr, $('.voidbtn', scr), s + 1.9);
  tl.fromTo(phoneBody, { x: 0 }, { x: 12, duration: 0.05, repeat: 7, yoyo: true, ease: 'none' }, s + 2.0).set(phoneBody, { x: 0 }, s + 2.42);
  sfx(s + 2.0, 'error');
  const sn = el(snack('Akun Anda tidak punya izin untuk aksi ini.', 'lock', '#E11D48'));
  sn.style.bottom = '16px';
  scr.append(sn);
  popIn(sn, s + 2.05);
  tl.fromTo($('.pr4', card), { backgroundColor: 'rgba(244,63,94,0)' }, { backgroundColor: 'rgba(244,63,94,.18)', duration: 0.2, yoyo: true, repeat: 3 }, s + 2.05);
  ovOut(card, s + FLEN - 0.15);
}

/* =========================== F12: MULTI DEVICE =========================== */
function f12() {
  const s = S(11);
  const pos = phonePos(250, 1190, 0.78);
  movePhone(pos, s - 0.2, 0.7);
  const scr = addScreen(posScreen('s12', ['kopi', 'mie', 'teh', 'roti', 'air', 'telur'], { held: 1 }));
  showScreen(scr, s - 0.05);
  hideScreen($('#s11'), s + 0.3);
  const cards = $$('.pcard', scr);
  const ts = [s + 1.0, s + 1.8, s + 2.6];
  ts.forEach((t, i) => { tapEl(scr, $('.photo', cards[i]), t, 'tap'); cardQty(cards[i], [[t, 1]]); });
  driveCartBar(scr, [[ts[0], 1, 18000], [ts[1], 2, 21500], [ts[2], 3, 26500]]);

  // tablet with the wide (catalog + cart) layout
  const tabCards = ['beras', 'telur', 'uht', 'donat', 'air', 'mie'];
  const tablet = el(`<div class="tablet ov" style="left:450px;top:1250px;width:590px;height:420px;padding:14px"><div class="scr"><div style="width:880px;height:600px;transform:scale(.6227);transform-origin:0 0;display:flex" class="app">
    <div style="width:64px;background:#0F172A;border-right:1px solid #1E293B;display:flex;flex-direction:column;align-items:center;gap:26px;padding-top:22px">${['layout-dashboard', 'shopping-cart', 'receipt-text', 'package', 'layout-grid'].map((x, i) => `<span style="width:44px;height:32px;border-radius:16px;display:grid;place-items:center;${i === 1 ? 'background:rgba(16,185,129,.16)' : ''}">${ic(x, 22, i === 1 ? '#10B981' : '#94A3B8')}</span>`).join('')}</div>
    <div style="flex:1;padding:12px;overflow:hidden">${catChips(0).replace('class="cats"', 'class="cats" style="padding:0"')}
      <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px">${tabCards.map((k) => productCard(P[k], k)).join('')}</div></div>
    <div style="width:250px;background:#020617;border-left:1px solid #1E293B;padding:14px;display:flex;flex-direction:column">
      <div style="font-size:15px;font-weight:700;margin-bottom:10px">Keranjang</div>
      ${['beras', 'telur'].map((k) => `<div class="row tci" style="gap:8px;padding:8px 0;border-bottom:1px solid #1E293B">${thumb(P[k], 34)}<div class="sp" style="font-size:12px;font-weight:600">${P[k].name}</div><b class="tab" style="font-size:12px">${rp(P[k].price)}</b></div>`).join('')}
      <div style="margin-top:auto" class="row"><span class="sp muted" style="font-size:13px">Total</span><b class="tab" style="font-size:20px;color:#10B981">Rp100.000</b></div>
      <div class="btn fill" style="margin-top:10px;height:46px">Bayar Rp100.000</div></div></div></div></div>`);
  OV.append(tablet);
  gsap.set(tablet, { autoAlpha: 0 });
  tl.fromTo(tablet, { autoAlpha: 0, x: 400, rotationY: -30, transformPerspective: 1600 }, { autoAlpha: 1, x: 0, rotationY: 0, duration: 0.7, ease: 'power3.out' }, s - 0.1);
  $$('.pcard', tablet).forEach((c) => { $('.sel', c).style.opacity = 0; });
  cardQty($$('.pcard', tablet)[0], [[s + 1.4, 1]]);
  cardQty($$('.pcard', tablet)[1], [[s + 2.2, 1]]);
  tl.fromTo($$('.tci', tablet), { autoAlpha: 0, x: 30 }, { autoAlpha: 1, x: 0, duration: 0.3, stagger: 0.8 }, s + 1.45);

  // owner's laptop: web dashboard updating live
  const lap = el(`<div class="laptop ov" style="left:190px;top:590px;width:700px">
    <div class="lid" style="height:430px"><div class="scr" style="background:#020617;color:#F1F5F9;display:flex">
      <div style="width:150px;background:#0F172A;border-right:1px solid #1E293B;padding:16px 12px"><div class="row" style="gap:8px;font-weight:800;font-size:14px"><img src="icon.png" style="width:24px;height:24px;border-radius:6px">Kasir Toko</div>
        ${['Dashboard', 'Penjualan', 'Produk', 'Laporan', 'Pelanggan'].map((x, i) => `<div style="margin-top:${i ? 6 : 18}px;padding:7px 10px;border-radius:8px;font-size:12px;${i === 0 ? 'background:rgba(16,185,129,.16);color:#10B981;font-weight:700' : 'color:#94A3B8'}">${x}</div>`).join('')}</div>
      <div style="flex:1;padding:16px 18px"><div class="row"><div class="sp"><div style="font-size:17px;font-weight:800">Dashboard</div><div style="font-size:11px;color:#94A3B8">Toko Berkah Jaya · Hari ini</div></div>
        <span class="row live" style="gap:6px;font-size:11px;font-weight:700;color:#34D399;padding:4px 10px;border-radius:20px;background:rgba(16,185,129,.14)"><span class="ld" style="width:7px;height:7px;border-radius:50%;background:#34D399"></span>LIVE dari kasir</span></div>
        <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:14px">
          ${[['Omzet', 'k1', '#fff'], ['Laba Kotor', 'k2', '#34D399'], ['Transaksi', 'k3', '#fff']].map(([l, c, col]) => `<div style="padding:12px;border-radius:12px;background:#0F172A;border:1px solid #1E293B"><div style="font-size:11px;color:#94A3B8">${l}</div><div class="tab ${c}" style="font-size:18px;font-weight:800;margin-top:4px;color:${col}"></div></div>`).join('')}</div>
        <div style="margin-top:12px;padding:12px;border-radius:12px;background:#0F172A;border:1px solid #1E293B;height:200px"><div style="font-size:12px;font-weight:700">Tren omzet per jam</div>
          <svg viewBox="0 0 440 150" width="100%" height="160" style="margin-top:4px"><defs><linearGradient id="ga" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#10B981" stop-opacity=".45"/><stop offset="1" stop-color="#10B981" stop-opacity="0"/></linearGradient></defs>
            <path class="area" d="M0 130 L40 118 L80 120 L120 96 L160 100 L200 78 L240 84 L280 60 L320 66 L360 40 L400 46 L440 18 L440 150 L0 150Z" fill="url(#ga)"/>
            <path class="line" d="M0 130 L40 118 L80 120 L120 96 L160 100 L200 78 L240 84 L280 60 L320 66 L360 40 L400 46 L440 18" fill="none" stroke="#34D399" stroke-width="3" stroke-dasharray="700" stroke-dashoffset="700"/></svg></div></div></div></div>
    <div class="base"></div></div>`);
  OV.append(lap);
  gsap.set(lap, { autoAlpha: 0 });
  tl.fromTo(lap, { autoAlpha: 0, y: -120, rotationX: 40, transformPerspective: 1600 }, { autoAlpha: 1, y: 0, rotationX: 0, duration: 0.7, ease: 'power3.out' }, s - 0.05);
  tl.to($('.line', lap), { strokeDashoffset: 0, duration: 1.4, ease: 'power2.inOut' }, s + 0.4)
    .fromTo($('.area', lap), { opacity: 0 }, { opacity: 1, duration: 1.0 }, s + 0.7)
    .fromTo($('.ld', lap), { opacity: 1 }, { opacity: 0.2, duration: 0.3, repeat: 9, yoyo: true }, s + 0.3);
  const sales = [[s + 1.25, 18000], [s + 1.65, 72000], [s + 2.05, 3500], [s + 2.45, 28000], [s + 2.85, 5000]];
  const step = (base, f) => (t) => { let v = base; for (const [tt, a] of sales) if (t >= tt) v += f(a); return v; };
  const k1 = step(4850000, (a) => a), k2 = step(1455000, (a) => Math.round(a * 0.3)), k3 = step(86, () => 1);
  at((t) => { $('.k1', lap).textContent = rp(k1(t)); $('.k2', lap).textContent = rp(k2(t)); $('.k3', lap).textContent = String(k3(t)); });
  sales.forEach(([t]) => tl.fromTo($$('.k1,.k2,.k3', lap), { color: '#6EE7B7' }, { color: (i) => ['#fff', '#34D399', '#fff'][i], duration: 0.5, immediateRender: false }, t));

  // cloud hub + data links
  const hub = { x: 540, y: 1140 };
  const ends = [{ x: 540, y: 1060 }, stageXY(pos, 180, 40), { x: 745, y: 1255 }];
  const svg = el(`<svg class="ov" width="1080" height="1920" style="left:0;top:0;z-index:55">${ends.map((e) => `<path d="M${hub.x} ${hub.y} L${e.x} ${e.y}" stroke="#34D399" stroke-width="4" stroke-dasharray="10 12" fill="none" opacity=".8"/>`).join('')}</svg>`);
  OV.append(svg);
  gsap.set(svg, { autoAlpha: 0 });
  tl.to(svg, { autoAlpha: 1, duration: 0.3 }, s + 0.5).fromTo($$('path', svg), { strokeDashoffset: 0 }, { strokeDashoffset: -220, duration: 3, ease: 'none' }, s + 0.5);
  const cloud = ov(el(`<div class="ov" style="width:120px;height:120px;margin:-60px;border-radius:50%;background:#0F172A;border:3px solid #34D399;display:grid;place-items:center;box-shadow:0 0 50px rgba(52,211,153,.5);z-index:56">${ic('cloud', 60, '#34D399', 2.2)}</div>`), hub.x, hub.y);
  ovIn(cloud, s + 0.45, { scale: 0.2 });
  sales.forEach(([t], i) => {
    const from = i % 2 ? ends[2] : ends[1];
    const pk = ov(el(`<div class="ov" style="width:20px;height:20px;margin:-10px;border-radius:50%;background:#A7F3D0;box-shadow:0 0 18px 6px rgba(52,211,153,.8);z-index:57"></div>`), from.x, from.y);
    tl.set(pk, { autoAlpha: 1 }, t - 0.45)
      .fromTo(pk, { x: 0, y: 0 }, { x: hub.x - from.x, y: hub.y - from.y, duration: 0.22, ease: 'none' }, t - 0.45)
      .to(pk, { x: ends[0].x - from.x, y: ends[0].y - from.y, duration: 0.2, ease: 'none' }, t - 0.23)
      .set(pk, { autoAlpha: 0 }, t - 0.02);
    sfx(t, 'blip');
  });
  const labels = [['smartphone', 'Kasir · HP', 90, 1810], ['tablet', 'Kasir · Tablet', 620, 1700], ['laptop', 'Pemilik · Laptop', 690, 545]];
  labels.forEach(([i, l, x, y], k) => { const n = ov(toast(i, l, '#0F766E', 'font-size:24px;padding:10px 20px 10px 10px'), x, y); $('.ib', n).style.cssText += 'width:42px;height:42px'; ovIn(n, s + 0.7 + k * 0.15); });
  // everything leaves for the outro
  tl.to([tablet, lap, svg, cloud, ...$$('.ov', OV).filter((n) => n.classList.contains('toast'))], { autoAlpha: 0, scale: 0.9, duration: 0.3, ease: 'power2.in' }, OUT0 - 0.15);
}

/* =========================== OUTRO =========================== */
function outro() {
  const O = $('#outro');
  const t0 = OUT0;
  tl.to(phone, { y: 2100, rotationX: -20, duration: 0.5, ease: 'power3.in' }, t0 - 0.2);
  sfx(t0 - 0.15, 'whoosh');
  const title = el(`<div style="position:absolute;left:0;right:0;top:250px;text-align:center;font-size:84px;font-weight:850;letter-spacing:-3px;line-height:1.05"><div class="ol" style="overflow:hidden;padding-bottom:6px"><span style="display:inline-block">Semua yang toko</span></div><div class="ol" style="overflow:hidden;padding-bottom:6px"><span class="hl" style="display:inline-block">butuhkan, ada!</span></div></div>`);
  const tiles = [['wifi-off', 'Jualan Offline'], ['qr-code', 'QRIS Otomatis'], ['printer', 'Struk Bluetooth'], ['monitor', 'Layar Pembeli'], ['pause', 'Tunda Keranjang'], ['hand-coins', 'Catat Kasbon'], ['wallet', 'Cek Uang Laci'], ['chart-column-increasing', 'Laba Otomatis'], ['store', 'Preset Toko'], ['package-plus', 'Stok Fleksibel'], ['shield-check', 'Akses Aman'], ['laptop', 'Pantau di Mana Saja']];
  const grid = el(`<div class="ogrid">${tiles.map(([i, l]) => `<div class="otile"><div class="ib">${ic(i, 48, '#34D399', 2.2)}</div>${l}</div>`).join('')}</div>`);
  O.append(title, grid);
  const ts = $$('.otile', grid);
  gsap.set([title, grid], { autoAlpha: 0 });
  tl.set([title, grid], { autoAlpha: 1 }, t0)
    .fromTo($$('.ol span', title), { yPercent: 110 }, { yPercent: 0, duration: 0.55, stagger: 0.1, ease: 'power4.out' }, t0 + 0.1)
    .fromTo(ts, { autoAlpha: 0, scale: 0.4, y: 60 }, { autoAlpha: 1, scale: 1, y: 0, duration: 0.45, stagger: { each: 0.06, from: 'start' }, ease: 'back.out(2)' }, t0 + 0.3);
  ts.forEach((_, i) => sfx(t0 + 0.3 + i * 0.06, 'tick'));
  tl.fromTo($$('.ib', grid), { boxShadow: '0 0 0 0 rgba(52,211,153,0)' }, { boxShadow: '0 0 30px 4px rgba(52,211,153,.45)', duration: 0.3, stagger: 0.04, yoyo: true, repeat: 1 }, t0 + 1.4);
  const tC = t0 + 6 * BEAT; // ~53.4s
  tl.to(ts, { scale: 0, autoAlpha: 0, x: (i) => (1 - (i % 3)) * 320, y: (i) => (1.5 - Math.floor(i / 3)) * 258, duration: 0.45, stagger: 0.015, ease: 'power3.in' }, tC - 0.45)
    .to(title, { autoAlpha: 0, y: -60, duration: 0.35, ease: 'power2.in' }, tC - 0.4);

  const end = el(`<div style="position:absolute;inset:0">
    <div class="eglow" style="position:absolute;left:190px;top:330px;width:700px;height:700px;border-radius:50%;background:radial-gradient(circle,rgba(16,185,129,.5),rgba(16,185,129,0) 65%)"></div>
    <img class="elogo" src="icon.png" style="position:absolute;left:400px;top:440px;width:280px;height:280px;border-radius:70px;box-shadow:0 30px 90px rgba(16,185,129,.6)">
    <div class="ewm" style="position:absolute;left:0;right:0;top:770px;text-align:center;font-size:132px;font-weight:900;letter-spacing:-5px">Kasir Toko</div>
    <div class="etag" style="position:absolute;left:0;right:0;top:940px;text-align:center;font-size:40px;font-weight:500;color:#CBD5E1">Kasir pintar untuk <b class="hl" style="font-weight:800">toko Indonesia</b></div>
    <div class="ecta" style="position:absolute;left:0;right:0;top:1060px;text-align:center"><span class="cta">${ic('rocket', 46, '#fff', 2.4)}Coba Gratis Sekarang</span></div>
    <div class="ewa" style="position:absolute;left:0;right:0;top:1270px;text-align:center"><span style="display:inline-flex;align-items:center;gap:22px;padding:22px 44px 22px 22px;border-radius:999px;background:rgba(37,211,102,.12);border:2.5px solid rgba(37,211,102,.6)">
      <span style="width:84px;height:84px;border-radius:50%;background:#25D366;display:grid;place-items:center">${ic('phone-call', 44, '#fff', 2.4)}</span>
      <span style="text-align:left"><span style="display:block;font-size:28px;font-weight:600;color:#86EFAC">Hubungi / WhatsApp</span><b class="tab" style="font-size:64px;font-weight:900;letter-spacing:-1px">0857-7777-5477</b></span></span></div>
    <div class="eurl" style="position:absolute;left:0;right:0;top:1480px;text-align:center;font-size:38px;font-weight:700;color:#E2E8F0"><span style="display:inline-flex;align-items:center;gap:14px">${ic('globe', 38, '#34D399')}kasirtoko.biz.id</span></div>
    <div class="edev" style="position:absolute;left:0;right:0;top:1570px;display:flex;justify-content:center;gap:16px">${[['smartphone', 'HP'], ['tablet', 'Tablet'], ['laptop', 'Laptop']].map(([i, l]) => `<span style="display:inline-flex;align-items:center;gap:10px;padding:12px 24px;border-radius:999px;background:#0F172A;border:1.5px solid #334155;font-size:28px;font-weight:600;color:#CBD5E1">${ic(i, 30, '#94A3B8')}${l}</span>`).join('')}</div></div>`);
  O.append(end);
  const [glow, logo, wm, tag, cta, wa, url, dev] = ['.eglow', '.elogo', '.ewm', '.etag', '.ecta', '.ewa', '.eurl', '.edev'].map((q) => $(q, end));
  gsap.set([glow, logo, wm, tag, cta, wa, url, dev], { autoAlpha: 0 });
  tl.fromTo(logo, { autoAlpha: 0, scale: 0, rotate: -30 }, { autoAlpha: 1, scale: 1, rotate: 0, duration: 0.7, ease: 'back.out(2.2)' }, tC)
    .fromTo(glow, { autoAlpha: 0, scale: 0.3 }, { autoAlpha: 1, scale: 1, duration: 0.9, ease: 'power2.out' }, tC)
    .fromTo('#flash', { opacity: 0.4 }, { opacity: 0, duration: 0.5, immediateRender: false }, tC)
    .fromTo(wm, { autoAlpha: 0, y: 50, scale: 0.9 }, { autoAlpha: 1, y: 0, scale: 1, duration: 0.5, ease: 'power3.out' }, tC + 0.3)
    .fromTo(tag, { autoAlpha: 0, y: 20 }, { autoAlpha: 1, y: 0, duration: 0.4 }, tC + 0.6)
    .fromTo(cta, { autoAlpha: 0, scale: 0.5 }, { autoAlpha: 1, scale: 1, duration: 0.55, ease: 'back.out(2.5)' }, tC + 0.95)
    .fromTo(wa, { autoAlpha: 0, scale: 0.6, y: 30 }, { autoAlpha: 1, scale: 1, y: 0, duration: 0.55, ease: 'back.out(2.2)' }, tC + 1.35)
    .fromTo(url, { autoAlpha: 0, y: 20 }, { autoAlpha: 1, y: 0, duration: 0.4 }, tC + 1.75)
    .fromTo(dev, { autoAlpha: 0, y: 20 }, { autoAlpha: 1, y: 0, duration: 0.4 }, tC + 1.95)
    .fromTo($('.cta', cta), { scale: 1 }, { scale: 1.05, duration: BEAT, repeat: 7, yoyo: true, ease: 'sine.inOut' }, tC + 1.5)
    .fromTo(logo, { y: 0 }, { y: -14, duration: BEAT * 2, repeat: 3, yoyo: true, ease: 'sine.inOut' }, tC + 0.8);
  sfx(tC, 'impact'); sfx(tC + 0.95, 'pop'); sfx(tC + 1.35, 'pop'); sfx(tC + 1.75, 'tick');
}

/* =========================== BUILD =========================== */
function build() {
  $('#phoneno .wa').innerHTML = ic('phone-call', 22, '#fff', 2.4);
  buildBackground();
  buildHeadlines();
  buildIntro();
  buildPhone();
  f1(); f2(); f3(); f4(); f5(); f6(); f7(); f8(); f9(); f10(); f11(); f12();
  outro();
  tl.set({}, {}, DURATION);
  SFX.sort((a, b) => a.t - b.t);
  window.seek(0);
  window.READY = true;
}
document.fonts.ready.then(() => setTimeout(build, 50));
