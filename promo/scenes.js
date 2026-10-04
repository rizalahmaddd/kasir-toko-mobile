/* Scene timeline: intro, 12 feature vignettes, outro. */

const FEATS = [
  { chip: 'Mode Offline', icon: 'wifi-off', h: ['Sinyal hilang?', '*Tetap jualan!*'], sub: 'Internet putus atau mati lampu, kasir tetap jalan. Data terkirim otomatis saat online lagi.' },
  { chip: 'QRIS Dinamis', icon: 'qr-code', h: ['QRIS otomatis,', '*nominal pas!*'], sub: 'Angka di QRIS langsung sama dengan total belanja. Anti salah ketik & hitung.' },
  { chip: 'Struk Bluetooth', icon: 'printer', h: ['Cetak struk', '*langsung dari HP*'], sub: 'Pakai printer thermal Bluetooth mini. Tanpa kabel ribet.' },
  { chip: 'Layar Pelanggan', icon: 'monitor', h: ['Pembeli ikut', '*lihat belanjaan*'], sub: 'Layar kedua menampilkan daftar barang & total harga. Pembeli makin percaya.' },
  { chip: 'Transaksi Tertunda', icon: 'pause', h: ['Antrean panik?', '*Tunda dulu!*'], sub: 'Pembeli lupa bawa uang? Simpan keranjangnya, layani antrean berikutnya.' },
  { chip: 'Kasbon & Piutang', icon: 'hand-coins', h: ['Utang & kasbon', '*tercatat rapi*'], sub: 'Ada pengingat jatuh tempo dan catatan cicilan tiap pelanggan.' },
  { chip: 'Shift & Kas Laci', icon: 'wallet', h: ['Uang laci', '*selalu cocok*'], sub: 'Tiap ganti kasir, uang tunai di laci langsung dicocokkan dengan catatan.' },
  { chip: 'Laba Otomatis', icon: 'chart-column-increasing', h: ['Langsung tahu', '*untungnya*'], sub: 'Bukan cuma omzet. Modal barang (HPP) & untung dihitung otomatis.' },
  { chip: 'Preset Jenis Toko', icon: 'store', h: ['Siap pakai', '*sesuai jenis toko*'], sub: 'Kelontong, kafe, toko baju, bengkel, hingga apotek. Tanpa setting rumit.' },
  { chip: 'Stok Fleksibel', icon: 'package-plus', h: ['Stok belum dicatat?', '*Tetap bisa jual*'], sub: 'Barang baru dari supplier langsung dijual, hitung stoknya belakangan.' },
  { chip: 'Hak Akses Kasir', icon: 'shield-check', h: ['Rahasia modal', '*tetap aman*'], sub: 'Kasir cuma melayani. Harga modal, laporan untung & hapus transaksi terkunci.' },
  { chip: 'Multi Perangkat', icon: 'laptop', h: ['Pantau toko', '*dari mana saja*'], sub: 'Kasir pakai HP/tablet, pemilik pantau laporan lewat HP atau laptop.' },
];
const S = (i) => FEAT0 + i * FLEN;
const PH = phonePos(540, 600, 1.72);
const stageXY = (pos, dx, dy) => ({ x: pos.x + (12 + dx) * pos.scale, y: pos.y + (12 + dy) * pos.scale });

function offsetIn(node, root) {
  let x = 0, y = 0, n = node;
  while (n && n !== root) { x += n.offsetLeft; y += n.offsetTop; n = n.offsetParent; }
  return { x, y, w: node.offsetWidth, h: node.offsetHeight, cx: x + node.offsetWidth / 2, cy: y + node.offsetHeight / 2 };
}
function tapEl(scr, node, t, sound = 'tap', dy = 0) {
  const o = offsetIn(node, scr);
  tap(scr, o.cx, o.cy + dy, t, sound);
  press(node, t);
  return o;
}
function centerDialog(d, h = 736) { d.style.top = Math.round((h - d.offsetHeight) / 2) + 'px'; }

let phone, phoneBody, VP;
const stage = $('#stage');
const OV = $('#overlays');
const DEV = $('#devices');

/** Cross-fades phone screens: the new one fades/zooms in over the old one. */
function showScreen(scr, t, dur = 0.3) {
  tl.fromTo(scr, { autoAlpha: 0, scale: 1.04 }, { autoAlpha: 1, scale: 1, duration: dur, ease: 'power2.out' }, t);
}
function hideScreen(scr, t, dur = 0.2) { tl.to(scr, { autoAlpha: 0, duration: dur }, t); }
function addScreen(scr) { VP.append(scr); gsap.set(scr, { autoAlpha: 0 }); return scr; }
function ov(node, x, y) { node.style.left = x + 'px'; node.style.top = y + 'px'; OV.append(node); gsap.set(node, { autoAlpha: 0 }); return node; }
function ovC(node, y) { const n = ov(node, 540, y); n.style.translate = '-50% 0'; return n; }
function ovIn(node, t, from = { scale: 0.6, y: 30 }) {
  tl.fromTo(node, { autoAlpha: 0, ...from }, { autoAlpha: 1, scale: 1, y: 0, x: 0, duration: 0.45, ease: 'back.out(2)' }, t);
  sfx(t, 'pop');
}
function ovOut(node, t) { tl.to(node, { autoAlpha: 0, scale: 0.85, duration: 0.22, ease: 'power2.in' }, t); }
function wifiOff(t) {
  tl.to($$('.wifi-on'), { opacity: 0, duration: 0.1 }, t).to($$('.wifi-off'), { opacity: 1, duration: 0.1 }, t);
}
function wifiOn(t) {
  tl.to($$('.wifi-off'), { opacity: 0, duration: 0.1 }, t).to($$('.wifi-on'), { opacity: 1, duration: 0.1 }, t);
}

/* =========================== BACKGROUND =========================== */
function buildBackground() {
  const r = rng(42);
  const pc = $('#particles');
  for (let i = 0; i < 34; i++) {
    const p = el(`<div class="particle"></div>`);
    const s = 3 + r() * 7;
    Object.assign(p.style, { left: r() * 1080 + 'px', top: r() * 1920 + 'px', width: s + 'px', height: s + 'px', opacity: 0.12 + r() * 0.35 });
    if (r() > 0.7) p.style.background = '#2DD4BF';
    pc.append(p);
    tl.fromTo(p, { y: 0, x: 0 }, { y: -300 - r() * 500, x: (r() - 0.5) * 120, duration: DURATION, ease: 'none' }, 0);
  }
  tl.fromTo('#blob1', { scale: 0.9 }, { scale: 1.12, duration: BEAT * 8, repeat: 7, yoyo: true, ease: 'sine.inOut' }, 0);
  tl.fromTo('#blob2', { x: 0, y: 0 }, { x: 160, y: 120, duration: 30, repeat: 1, yoyo: true, ease: 'sine.inOut' }, 0);
  tl.fromTo('#blob3', { x: 0, y: 0 }, { x: -200, y: 260, duration: 30, repeat: 1, yoyo: true, ease: 'sine.inOut' }, 0);
  tl.fromTo('#bg-grid', { backgroundPosition: '0px 0px' }, { backgroundPosition: '0px -720px', duration: DURATION, ease: 'none' }, 0);

  // film grain
  const c = $('#grain'), g = c.getContext('2d'), img = g.createImageData(540, 960), rr = rng(7);
  for (let i = 0; i < img.data.length; i += 4) { const v = rr() * 255; img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255; }
  g.putImageData(img, 0, 0);
  c.style.transformOrigin = '0 0';
  at((t) => {
    const f = Math.floor(t * 30), q = rng(f + 1);
    c.style.transform = `translate(${-q() * 60}px, ${-q() * 60}px) scale(2.15)`;
  });

  // story progress
  const pr = $('#progress');
  for (let i = 0; i < 12; i++) {
    const seg = el(`<div class="seg"><i></i></div>`);
    pr.append(seg);
    tl.fromTo($('i', seg), { scaleX: 0 }, { scaleX: 1, duration: FLEN, ease: 'none' }, S(i));
  }
  tl.fromTo(pr, { autoAlpha: 0, y: -20 }, { autoAlpha: 1, y: 0, duration: 0.4 }, FEAT0 - 0.2).to(pr, { autoAlpha: 0, duration: 0.3 }, OUT0 + 0.1);
  tl.fromTo('#bug', { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.2 }, FEAT0 - 0.55).to('#bug', { autoAlpha: 0, duration: 0.3 }, OUT0 + 0.1);
}

/* =========================== HEADLINES =========================== */
function buildHeadlines() {
  const box = $('#feats');
  FEATS.forEach((f, i) => {
    const lines = f.h.map((line) => {
      const parts = [];
      line.replace(/\*([^*]+)\*|([^*]+)/g, (_, a, b) => { (a || b).trim().split(/\s+/).forEach((w) => parts.push(`<span class="w ${a ? 'hl' : ''}">${w}</span>`)); });
      return `<span class="line">${parts.join(' ')}</span>`;
    });
    const node = el(`<div class="feat"><div class="chiprow"><span class="num">${String(i + 1).padStart(2, '0')}</span>
      <span class="chip"><span class="icbox">${ic(f.icon, 24, '#fff', 2.4)}</span>${f.chip}</span></div>
      <h1>${lines.join('')}</h1><p>${f.sub}</p></div>`);
    box.append(node);
    const t0 = S(i), t1 = S(i) + FLEN;
    const words = $$('.w', node), chip = $('.chiprow', node), p = $('p', node);
    gsap.set(node, { autoAlpha: 0 });
    tl.set(node, { autoAlpha: 1 }, t0 - 0.05)
      .fromTo(chip, { autoAlpha: 0, x: -40 }, { autoAlpha: 1, x: 0, duration: 0.45, ease: 'power3.out' }, t0 - 0.05)
      .fromTo(words, { yPercent: 115, rotate: 4 }, { yPercent: 0, rotate: 0, duration: 0.6, ease: 'power4.out', stagger: 0.055 }, t0)
      .fromTo(p, { autoAlpha: 0, y: 24 }, { autoAlpha: 1, y: 0, duration: 0.5, ease: 'power2.out' }, t0 + 0.3)
      .to(words, { yPercent: -115, duration: 0.28, ease: 'power3.in', stagger: 0.015 }, t1 - 0.32)
      .to([chip, p], { autoAlpha: 0, y: -20, duration: 0.25, ease: 'power2.in' }, t1 - 0.3)
      .set(node, { autoAlpha: 0 }, t1);
    sfx(t0 - 0.18, 'whoosh');
  });
}

/* =========================== INTRO =========================== */
function buildIntro() {
  const I = $('#intro');
  const lines = el(`<div style="position:absolute;left:0;right:0;top:660px;text-align:center;font-weight:900;font-size:122px;line-height:1.06;letter-spacing:-4px">
    <div class="il" style="color:#F1F5F9">Masih ribet</div>
    <div class="il" style="color:#F1F5F9">nyatat jualan</div>
    <div class="il" style="position:relative;display:inline-block;color:#94A3B8">pakai buku?<i class="strike" style="position:absolute;left:-14px;right:-14px;top:54%;height:16px;border-radius:8px;background:#F43F5E;transform-origin:0 50%;box-shadow:0 0 30px rgba(244,63,94,.7)"></i></div></div>`);
  I.append(lines);
  const ils = $$('.il', lines);
  const doodles = [['notebook-pen', 120, 330, -14], ['calculator', 800, 420, 12], ['receipt', 150, 1260, 10], ['book-open', 780, 1250, -8]].map(([n, x, y, r]) =>
    el(`<div style="position:absolute;left:${x}px;top:${y}px;width:170px;height:170px;border-radius:44px;background:rgba(30,41,59,.85);border:2px solid #334155;display:grid;place-items:center;transform:rotate(${r}deg)">${ic(n, 92, '#94A3B8', 1.6)}</div>`));
  doodles.forEach((d) => I.append(d));

  const pre = el(`<div style="position:absolute;left:0;right:0;top:560px;text-align:center;font-size:46px;font-weight:600;color:#CBD5E1">Saatnya upgrade ke</div>`);
  const logoWrap = el(`<div style="position:absolute;left:390px;top:680px;width:300px;height:300px">
      <div class="ring" style="position:absolute;inset:0;border-radius:50%;border:6px solid #34D399"></div>
      <div class="ring" style="position:absolute;inset:0;border-radius:50%;border:4px solid #2DD4BF"></div>
      <img class="logo" src="icon.png" style="position:absolute;inset:0;width:300px;height:300px;border-radius:76px;box-shadow:0 30px 90px rgba(16,185,129,.55)"></div>`);
  const word = el(`<div style="position:absolute;left:0;right:0;top:1030px;text-align:center;font-size:140px;font-weight:900;letter-spacing:-5px;overflow:hidden;padding-bottom:10px">${'Kasir Toko'.split('').map((c) => `<span class="ch" style="display:inline-block">${c === ' ' ? '&nbsp;' : c}</span>`).join('')}</div>`);
  const tag = el(`<div style="position:absolute;left:0;right:0;top:1222px;text-align:center;font-size:42px;font-weight:500;color:#CBD5E1">Aplikasi kasir pintar untuk <b class="hl" style="font-weight:800">HP & tablet</b></div>`);
  const pill = el(`<div style="position:absolute;left:50%;top:1330px;transform:translateX(-50%)"><div class="fp" style="display:flex;align-items:center;gap:14px;padding:18px 34px;border-radius:999px;background:rgba(16,185,129,.14);border:2px solid rgba(52,211,153,.45);font-size:36px;font-weight:700;color:#6EE7B7;white-space:nowrap">${ic('sparkles', 36, '#6EE7B7')}12 fitur andalan untuk toko Anda</div></div>`);
  I.append(pre, logoWrap, word, tag, pill);
  const burst = [];
  const r = rng(3);
  for (let i = 0; i < 16; i++) {
    const d = el(`<div style="position:absolute;left:540px;top:830px;width:14px;height:14px;margin:-7px;border-radius:50%;background:${i % 2 ? '#34D399' : '#2DD4BF'}"></div>`);
    I.append(d); burst.push([d, (i / 16) * Math.PI * 2 + r() * 0.3, 260 + r() * 160]);
  }

  gsap.set([pre, logoWrap, word, tag, pill, ...doodles], { autoAlpha: 0 });
  gsap.set(ils, { autoAlpha: 0 });
  tl.fromTo('#blackout', { opacity: 1 }, { opacity: 0, duration: 0.5 }, 0);
  ils.forEach((l, i) => {
    tl.fromTo(l, { autoAlpha: 0, scale: 2.4, y: -30 }, { autoAlpha: 1, scale: 1, y: 0, duration: 0.32, ease: 'power4.out' }, i * BEAT);
    sfx(i * BEAT, 'hit');
  });
  doodles.forEach((d, i) => tl.fromTo(d, { autoAlpha: 0, scale: 0.3 }, { autoAlpha: 1, scale: 1, duration: 0.4, ease: 'back.out(2.5)' }, 0.25 + i * 0.22));
  tl.fromTo($('.strike', lines), { scaleX: 0 }, { scaleX: 1, duration: 0.25, ease: 'power3.out' }, 3 * BEAT)
    .fromTo(lines, { x: -14 }, { x: 0, duration: 0.4, ease: 'elastic.out(1.2,0.3)' }, 3 * BEAT + 0.2)
    .to(ils, { autoAlpha: 0, scale: 0.7, y: -60, filter: 'blur(10px)', duration: 0.35, ease: 'power3.in', stagger: 0.04 }, 4 * BEAT - 0.25)
    .to(doodles, { autoAlpha: 0, scale: 0.4, rotate: 40, duration: 0.3, ease: 'power3.in', stagger: 0.03 }, 4 * BEAT - 0.25);
  sfx(3 * BEAT, 'scratch');

  tl.fromTo(pre, { autoAlpha: 0, y: 30 }, { autoAlpha: 1, y: 0, duration: 0.4, ease: 'power3.out' }, 4 * BEAT + 0.05);
  const tL = 5 * BEAT;
  tl.fromTo(logoWrap, { autoAlpha: 0, scale: 0, rotate: -25 }, { autoAlpha: 1, scale: 1, rotate: 0, duration: 0.7, ease: 'back.out(2.2)' }, tL)
    .fromTo($$('.ring', logoWrap), { scale: 0.9, opacity: 0.9 }, { scale: 2.4, opacity: 0, duration: 0.9, ease: 'power2.out', stagger: 0.15 }, tL + 0.05)
    .fromTo('#flash', { opacity: 0.35 }, { opacity: 0, duration: 0.4, immediateRender: false }, tL);
  burst.forEach(([d, a, dist]) => tl.fromTo(d, { x: 0, y: 0, scale: 1, opacity: 1 }, { x: Math.cos(a) * dist, y: Math.sin(a) * dist, scale: 0, opacity: 0, duration: 0.9, ease: 'power3.out' }, tL));
  sfx(tL, 'impact');
  tl.fromTo($$('.ch', word), { yPercent: 110 }, { yPercent: 0, duration: 0.5, ease: 'power4.out', stagger: 0.035 }, 6 * BEAT)
    .set(word, { autoAlpha: 1 }, 6 * BEAT)
    .fromTo(tag, { autoAlpha: 0, y: 24 }, { autoAlpha: 1, y: 0, duration: 0.45 }, 7 * BEAT)
    .fromTo($('.fp', pill), { scale: 0.5 }, { scale: 1, duration: 0.5, ease: 'back.out(2.5)' }, 8 * BEAT)
    .set(pill, { autoAlpha: 1 }, 8 * BEAT);
  sfx(6 * BEAT, 'swish'); sfx(8 * BEAT, 'pop');
  // logo flies into the top-left brand bug while the phone rises
  const tOut = 9.5 * BEAT;
  tl.to([pre, tag, pill], { autoAlpha: 0, y: -30, duration: 0.3, ease: 'power2.in' }, tOut)
    .to(word, { autoAlpha: 0, scale: 0.6, y: -200, duration: 0.45, ease: 'power3.in' }, tOut)
    .to(logoWrap, { x: 48 - 390 - 124, y: 84 - 680 - 124, scale: 52 / 300, duration: 0.75, ease: 'power3.inOut' }, tOut)
    .to(logoWrap, { autoAlpha: 0, duration: 0.1 }, FEAT0 - 0.5);
}

/* =========================== PHONE =========================== */
function buildPhone() {
  phone = makePhone('phone');
  DEV.append(phone);
  phoneBody = $('.phone', phone);
  VP = vp(phone);
  gsap.set(phone, { ...PH, y: 2000, transformOrigin: '0 0' });
  tl.fromTo(phone, { y: 2000, rotationX: 30, transformPerspective: 1800 }, { y: PH.y, rotationX: 0, duration: 1.05, ease: 'power3.out' }, FEAT0 - 1.05);
  sfx(FEAT0 - 1.9, 'riser', { dur: 1.9 });
  sfx(FEAT0, 'drop');
  tl.fromTo('#flash', { opacity: 0.28 }, { opacity: 0, duration: 0.35, immediateRender: false }, FEAT0);
  // a little camera punch on every feature
  for (let i = 1; i < 12; i++) tl.fromTo(phoneBody, { scale: 1.025 }, { scale: 1, duration: 0.5, ease: 'power2.out', immediateRender: false }, S(i));
}
function movePhone(pos, t, dur = 0.6, ease = 'power3.inOut') { tl.to(phone, { ...pos, duration: dur, ease }, t); }

/* =========================== F1: OFFLINE =========================== */
function f1() {
  const s = S(0);
  const scr = addScreen(posScreen('s1', ['kopi', 'mie', 'teh', 'roti', 'telur', 'beras']));
  gsap.set(scr, { autoAlpha: 1 });
  const cards = $$('.pcard', scr);
  // power cut + network loss
  tl.to('#blackout', { keyframes: [{ opacity: 0.75, duration: 0.05 }, { opacity: 0.15, duration: 0.07 }, { opacity: 0.8, duration: 0.05 }, { opacity: 0.35, duration: 0.25 }] }, s + 0.12)
    .to('#blackout', { opacity: 0, duration: 0.4 }, s + 2.9)
    .to('#blobWarn', { opacity: 0.32, duration: 0.4 }, s + 0.2)
    .to('#blobWarn', { opacity: 0, duration: 0.5 }, s + 2.9)
    .to('#blob1', { opacity: 0.15, duration: 0.3 }, s + 0.15)
    .to('#blob1', { opacity: 0.55, duration: 0.5 }, s + 2.9);
  sfx(s + 0.12, 'powerdown');
  wifiOff(s + 0.25);
  const t1 = ov(toast('zap-off', 'Mati lampu', '#D97706'), 36, 1000);
  const t2 = ov(toast('wifi-off', 'Internet putus', '#E11D48'), 520, 1130);
  ovIn(t1, s + 0.35, { scale: 0.6, x: -60 }); ovIn(t2, s + 0.55, { scale: 0.6, x: 60 });
  ovOut(t1, s + 0.95); ovOut(t2, s + 1.05);

  tapEl(scr, $('.photo', cards[0]), s + 1.0);
  tapEl(scr, $('.photo', cards[1]), s + 1.35);
  tapEl(scr, $('.photo', cards[1]), s + 1.65);
  cardQty(cards[0], [[s + 1.0, 1], [s + 2.95, 0]]);
  cardQty(cards[1], [[s + 1.35, 1], [s + 1.65, 2], [s + 2.95, 0]]);
  driveCartBar(scr, [[s + 1.0, 1, 18000], [s + 1.35, 2, 21500], [s + 1.65, 3, 25000]]);
  tl.to($('.cartbar-wrap', scr), { yPercent: 110, duration: 0.3, ease: 'power2.in' }, s + 2.92);
  tap(scr, 180, 631, s + 2.0);

  const scrim = el(`<div class="scrim"></div>`);
  const dlg = el(`<div class="dialog" style="text-align:center;transform:none">
    <div style="display:flex;justify-content:center">${ic('cloud-off', 40, '#F59E0B')}</div>
    <div style="font-size:22px;font-weight:700;margin-top:12px">Tersimpan di perangkat</div>
    <div class="muted" style="font-size:14px;margin-top:6px;line-height:1.4">Server tidak terjangkau. Transaksi dikirim otomatis begitu koneksi kembali.</div>
    <div class="muted" style="margin-top:16px;font-size:14px">Kembalian</div>
    <div class="tab" style="font-size:36px;font-weight:700;color:var(--emerald400)">Rp25.000</div>
    <div class="btn out" style="margin-top:16px">${ic('printer', 18)}Cetak Struk</div>
    <div class="btn fill nb" style="margin-top:8px">Transaksi Baru</div></div>`);
  scr.append(scrim, dlg);
  centerDialog(dlg);
  gsap.set(dlg, { autoAlpha: 0 });
  tl.to(scrim, { opacity: 1, duration: 0.2 }, s + 2.15).to(scrim, { opacity: 0, duration: 0.2 }, s + 2.92);
  popIn(dlg, s + 2.18, 0.35, { scale: 0.9 });
  sfx(s + 2.2, 'save');
  tapEl(scr, $('.nb', dlg), s + 2.75);
  popOut(dlg, s + 2.88, 0.18, { scale: 0.95 });

  // back online
  wifiOn(s + 2.95);
  tl.fromTo('#flash', { opacity: 0.22 }, { opacity: 0, duration: 0.4, immediateRender: false }, s + 2.95);
  sfx(s + 2.95, 'powerup');
  const sn = el(snack('3 transaksi berhasil dikirim ke server', 'cloud-check'));
  scr.append(sn);
  popIn(sn, s + 3.05);
  const t3 = ovC(toast('cloud-check', 'Online lagi · tersinkron otomatis', '#059669'), 1650);
  ovIn(t3, s + 3.05);
  sfx(s + 3.1, 'success');
  ovOut(t3, s + FLEN - 0.15);
}

/* =========================== F2: QRIS =========================== */
function f2() {
  const s = S(1);
  const scr = addScreen(posScreen('s2', ['kopi', 'mie', 'teh', 'roti'], { navBadge: 9 }));
  showScreen(scr, s - 0.05, 0.25);
  hideScreen($('#s1'), s + 0.3);
  const cards = $$('.pcard', scr);
  [[0, 2], [1, 3], [2, 2], [3, 1]].forEach(([i, q]) => cardQty(cards[i], [[0, q]]));
  gsap.set($('.cartbar-wrap', scr), { yPercent: 0 });
  steps($('.cb-count', scr), [[0, '9 barang']]); steps($('.cb-total', scr), [[0, 'Rp87.000']]);
  const scrim = el(`<div class="scrim"></div>`);
  const sheet = el(`<div class="sheet" style="top:44px">${sheetHeader('Pembayaran')}<div class="sheet-b" style="overflow:hidden;position:absolute;left:0;right:0;top:68px;bottom:0"><div class="scroller">
      <div class="panel amtpanel"><div class="lb">Total tagihan</div><div class="v amtv">Rp87.000</div></div>
      <div class="mchips">${[['banknote', 'Tunai'], ['qr-code', 'QRIS'], ['landmark', 'Transfer'], ['credit-card', 'Kartu']].map(([i, l], k) => `<div class="mchip m${k}"><div class="onbg"></div>${ic(i, 16, k === 0 ? '#10B981' : '#F1F5F9')}<b>${l}</b></div>`).join('')}</div>
      <div style="height:16px"></div>
      <div class="cashpart">${moneyField('Uang diterima')}<div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px">${['Uang pas', 'Rp90.000', 'Rp100.000', 'Rp150.000'].map((x) => `<span class="achip">${x}</span>`).join('')}</div></div>
      <div class="qrispart"><div class="qris"><div class="top"><span class="logo">QRIS</span><span class="std">Standar Pembayaran Nasional</span>${ic('shield-check', 16, '#059669')}</div>
        <div class="mer"><b>TOKO BERKAH JAYA</b><span>Scan QR ini dengan GoPay, OVO, Dana, BCA, atau m-Banking</span></div>
        <div class="qrbox">${qrSvg(11)}<div style="position:absolute;left:50%;top:50%;width:38px;height:38px;margin:-19px;border-radius:9px;background:#fff;display:grid;place-items:center"><img src="icon.png" style="width:30px;height:30px;border-radius:7px"></div></div>
        <div class="amt"><div class="l">TOTAL PEMBAYARAN</div><div class="v qamt">Rp87.000</div><div class="wait"><span class="wdot" style="width:8px;height:8px;border-radius:50%;background:#059669"></span>Menunggu pembayaran pembeli</div></div></div>
        <div class="btn txt" style="margin-top:8px">${ic('sliders-horizontal', 15)}Ubah Nominal / Split QRIS</div></div>
      <div class="btn fill paybtn" style="height:54px;margin-top:16px"><span class="pl"></span></div>
      <div class="btn txt" style="margin-top:4px">${ic('plus', 16)}Bayar sebagian, sisanya metode lain</div>
    </div></div></div>`);
  scr.append(scrim, sheet);
  gsap.set(sheet, { yPercent: 100 });
  tl.to(scrim, { opacity: 1, duration: 0.25 }, s).to(sheet, { yPercent: 0, duration: 0.45, ease: 'power3.out' }, s);
  sfx(s, 'sheet');
  const tQ = s + 0.75;
  const qchip = $('.m1', sheet), cchip = $('.m0', sheet);
  // measure before toggling display
  const cashH = $('.cashpart', sheet).offsetHeight;
  const o = offsetIn(qchip, scr);
  tap(scr, o.cx, o.cy, tQ);
  press(qchip, tQ);
  const yAmt = offsetIn($('.amtv', sheet), scr).cy, yQ = offsetIn($('.qamt', sheet), scr).cy - cashH;
  const oPay = offsetIn($('.paybtn', sheet), scr);
  at((t) => {
    const q = t >= tQ;
    $('.onbg', cchip).style.opacity = q ? 0 : 1;
    $('.onbg', qchip).style.opacity = q ? 1 : 0;
    $('svg', cchip).setAttribute('stroke', q ? '#F1F5F9' : '#10B981');
    $('svg', qchip).setAttribute('stroke', q ? '#10B981' : '#F1F5F9');
    $('.cashpart', sheet).style.display = q ? 'none' : '';
    $('.qrispart', sheet).style.display = q ? '' : 'none';
    $('.pl', sheet).textContent = q ? 'Pembayaran QRIS Diterima' : 'Selesaikan Pembayaran';
  });
  tl.fromTo($('.qris', sheet), { scale: 0.85, autoAlpha: 0 }, { scale: 1, autoAlpha: 1, duration: 0.45, ease: 'back.out(1.8)' }, tQ + 0.08);
  counter($('.qamt', sheet), tQ + 0.1, 0.5, 0, 87000);
  sfx(tQ + 0.15, 'qr');
  // brightness boost glow
  tl.fromTo($('.qris', sheet), { boxShadow: '0 0 0 rgba(255,255,255,0)' }, { boxShadow: '0 0 60px rgba(255,255,255,.35)', duration: 0.6 }, tQ + 0.3);
  tl.fromTo($('.wdot', sheet), { scale: 1, opacity: 1 }, { scale: 1.6, opacity: 0.3, duration: 0.45, repeat: 3, yoyo: true, ease: 'sine.inOut' }, tQ + 0.5);

  // bracket callout tying the bill total to the QR nominal
  const yA = stageXY(PH, 0, yAmt).y, yB = stageXY(PH, 0, yQ).y;
  const xR = stageXY(PH, 360, 0).x + 16;
  const br = el(`<svg class="ov" width="1080" height="1920" style="left:0;top:0;overflow:visible"><path class="bp" d="M${xR - 30} ${yA} H${xR + 40} V${yB} H${xR - 30}" fill="none" stroke="#34D399" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="2000" stroke-dashoffset="2000"/></svg>`);
  OV.append(br);
  const eq = ov(el(`<div class="ov" style="width:96px;height:96px;border-radius:50%;background:#10B981;display:grid;place-items:center;box-shadow:0 0 0 8px rgba(16,185,129,.25),0 20px 40px rgba(0,0,0,.5)">${ic('check-check', 52, '#fff', 2.6)}</div>`), xR + 40 - 48, (yA + yB) / 2 - 48);
  tl.to($('.bp', br), { strokeDashoffset: 0, duration: 0.55, ease: 'power2.inOut' }, tQ + 0.55).to(br, { opacity: 0, duration: 0.25 }, s + 2.25);
  ovIn(eq, tQ + 0.95, { scale: 0.2 }); ovOut(eq, s + 2.25);
  const lbl = ovC(toast('qr-code', 'Nominal QRIS = total belanja', '#10B981'), 1700);
  ovIn(lbl, tQ + 1.0); ovOut(lbl, s + 2.25);

  // buyer pays → cashier confirms
  const paid = ov(el(`<div class="ov glass" style="display:flex;align-items:center;gap:18px;padding:20px 30px 20px 20px;border-radius:26px">
      <div style="width:64px;height:64px;border-radius:18px;background:#0ea5e9;display:grid;place-items:center">${ic('smartphone', 34, '#fff')}</div>
      <div><div style="font-size:22px;color:#94A3B8;font-weight:600">HP pembeli · e-wallet</div><div style="font-size:30px;font-weight:800">Pembayaran berhasil ✓</div></div></div>`), 60, 1480);
  ovIn(paid, s + 2.3, { x: -80, scale: 0.8 }); ovOut(paid, s + 3.0);
  tl.to($('.scroller', sheet), { y: -130, duration: 0.35, ease: 'power2.inOut' }, s + 2.2);
  tap(scr, oPay.cx, oPay.cy - cashH - 130, s + 2.6);
  press($('.paybtn', sheet), s + 2.6);
  tl.to(sheet, { yPercent: 100, duration: 0.3, ease: 'power2.in' }, s + 2.72);
  okDialog(scr, s + 2.85);
  sfx(s + 2.85, 'cash');
}
function okDialog(scr, t) {
  const d = el(`<div class="dialog okdlg" style="transform:none">
    <div style="width:60px;height:60px;border-radius:50%;background:rgba(52,211,153,.14);display:grid;place-items:center;margin:0 auto">${ic('circle-check', 36, '#34D399')}</div>
    <div style="text-align:center;font-size:22px;font-weight:700;margin-top:14px">Transaksi berhasil</div>
    <div class="muted" style="text-align:center;font-size:13px;margin-top:2px">INV/20261004/0087</div>
    <div class="tab" style="text-align:center;font-size:28px;font-weight:800;margin-top:18px">Rp87.000</div>
    <div style="display:flex;gap:8px;margin-top:20px"><div class="btn out" style="flex:1">${ic('receipt-text', 18)}Lihat Struk</div><div class="btn out" style="flex:1">${ic('message-circle', 18)}WhatsApp</div></div>
    <div class="btn out printbtn" style="margin-top:8px">${ic('printer', 18)}Cetak Struk</div>
    <div class="btn fill" style="margin-top:8px">Transaksi Baru</div></div>`);
  scr.append(d);
  centerDialog(d);
  gsap.set(d, { autoAlpha: 0 });
  popIn(d, t, 0.4, { scale: 0.85 });
  tl.fromTo($('svg', d), { scale: 0, rotate: -90 }, { scale: 1, rotate: 0, duration: 0.5, ease: 'back.out(3)' }, t + 0.1);
  return d;
}

/* =========================== F3: PRINT =========================== */
function f3() {
  const s = S(2);
  const pos = phonePos(300, 700, 1.38);
  movePhone(pos, s - 0.15, 0.65);
  const scr = $('#s2');
  const dlg = $('.okdlg', scr);
  const printer = el(`<div class="printer ov" style="left:640px;top:1440px">
      <div class="paperclip"><div class="paper">
        <div class="c b" style="font-size:15px">TOKO BERKAH JAYA</div><div class="c">Jl. Merdeka No. 12, Malang</div><div class="c">0812-3456-7890</div>
        <div class="hr"></div><div>INV/20261004/0087</div><div class="r"><span>04/10/2026 09:41</span><span>Rina</span></div><div class="hr"></div>
        <div>Kopi Susu Gula Aren</div><div class="r"><span>&nbsp;2 x 18.000</span><span>36.000</span></div>
        <div>Indomie Goreng</div><div class="r"><span>&nbsp;3 x 3.500</span><span>10.500</span></div>
        <div>Roti Tawar Gandum</div><div class="r"><span>&nbsp;1 x 16.500</span><span>16.500</span></div>
        <div>Telur Ayam Negeri</div><div class="r"><span>&nbsp;0,5 kg x 28.000</span><span>14.000</span></div>
        <div>Teh Botol Sosro</div><div class="r"><span>&nbsp;2 x 5.000</span><span>10.000</span></div>
        <div class="hr"></div><div class="r b" style="font-size:15px"><span>TOTAL</span><span>87.000</span></div><div class="r"><span>QRIS</span><span>87.000</span></div>
        <div class="hr"></div><div class="c">Terima kasih</div><div class="c">sudah belanja :)</div><div class="c" style="margin-top:6px;font-size:11px">kasirtoko.biz.id</div></div></div>
      <div class="body"><div class="brand">THERMAL 58</div><div class="led"></div><div class="btnp"></div></div><div class="lid"></div><div class="slot"></div></div>`);
  OV.append(printer);
  // body must cover paper bottom: draw order already puts body after paper
  gsap.set(printer, { autoAlpha: 0 });
  gsap.set(printer, { transformOrigin: '50% 100%', scale: 1.35 });
  tl.fromTo(printer, { autoAlpha: 0, x: 500, rotate: 18 }, { autoAlpha: 1, x: 0, rotate: 0, duration: 0.65, ease: 'back.out(1.4)' }, s - 0.05);
  sfx(s, 'swish');
  const paper = $('.paper', printer);
  gsap.set(paper, { yPercent: 102 });
  tl.to(paper, { yPercent: 0, duration: 2.0, ease: 'steps(48)' }, s + 1.05);
  sfx(s + 1.05, 'print', { dur: 2.0 });
  tl.fromTo($('.led', printer), { opacity: 1 }, { opacity: 0.2, duration: 0.12, repeat: 15, yoyo: true }, s + 0.75);
  tl.fromTo(printer, { y: 0 }, { y: 2, duration: 0.05, repeat: 39, yoyo: true }, s + 1.05);

  tapEl(scr, $('.printbtn', dlg), s + 0.55);
  // bluetooth link
  const bt = ov(el(`<div class="ov" style="width:110px;height:110px;z-index:70">
      <div class="wv" style="position:absolute;inset:0;border-radius:50%;border:4px solid #38BDF8"></div><div class="wv" style="position:absolute;inset:0;border-radius:50%;border:4px solid #38BDF8"></div>
      <div style="position:absolute;inset:0;border-radius:50%;background:#0284C7;display:grid;place-items:center;box-shadow:0 0 40px rgba(14,165,233,.6)">${ic('bluetooth', 56, '#fff', 2.4)}</div></div>`), 600, 1250);
  ovIn(bt, s + 0.62, { scale: 0.2 });
  tl.fromTo($$('.wv', bt), { scale: 1, opacity: 0.9 }, { scale: 2.3, opacity: 0, duration: 0.8, stagger: 0.25, repeat: 2, ease: 'power2.out' }, s + 0.7);
  ovOut(bt, s + 2.6);
  const cap = ov(toast('bluetooth', 'Tersambung · Printer 58mm', '#0284C7', 'font-size:24px;padding:12px 22px 12px 12px'), 620, 1800);
  $('.ib', cap).style.cssText += 'width:44px;height:44px';
  ovIn(cap, s + 0.9); ovOut(cap, s + FLEN - 0.1);
  sfx(s + 3.1, 'ding');
  // exit
  tl.to(printer, { x: 700, rotate: 20, duration: 0.5, ease: 'power3.in' }, s + FLEN - 0.25).set(printer, { autoAlpha: 0 }, s + FLEN + 0.3);
}

/* =========================== F4: CUSTOMER DISPLAY =========================== */
function f4() {
  const s = S(3);
  const pos = phonePos(285, 1010, 1.1);
  movePhone(pos, s - 0.2, 0.65);
  const scr = addScreen(posScreen('s4', ['kopi', 'roti', 'teh', 'mie', 'air', 'telur'], { held: 1 }));
  showScreen(scr, s + 0.05);
  hideScreen($('#s2'), s + 0.35);
  const cards = $$('.pcard', scr);
  const order = [[0, 'kopi'], [1, 'roti'], [2, 'teh'], [3, 'mie']];
  const times = [s + 0.75, s + 1.25, s + 1.75, s + 2.25];
  let sum = 0;
  const cart = [];
  order.forEach(([ci, k], i) => { sum += P[k].price; cart.push([times[i], i + 1, sum]); cardQty(cards[ci], [[times[i], 1]]); tapEl(scr, $('.photo', cards[ci]), times[i]); });
  driveCartBar(scr, cart);

  const tab = el(`<div class="tablet" style="left:290px;top:580px;width:770px;height:540px"><div class="scr" style="font-family:Inter"><div style="zoom:1.3;width:554px;height:391px">
      <div style="height:64px;display:flex;align-items:center;gap:14px;padding:0 24px;background:#0F172A;border-bottom:1px solid #1E293B">
        <img src="icon.png" style="width:38px;height:38px;border-radius:10px"><div><div style="font-size:19px;font-weight:800">Toko Berkah Jaya</div><div style="font-size:12px;color:#94A3B8">Layar Pelanggan</div></div>
        <div style="flex:1"></div><div style="display:flex;align-items:center;gap:8px;font-size:13px;color:#CBD5E1;padding:6px 12px;border-radius:20px;background:#1E293B"><span class="dot8"></span>Dilayani oleh Rina</div></div>
      <div style="display:flex;height:calc(100% - 64px)">
        <div style="flex:1;padding:14px 14px;min-width:0"><div style="font-size:12px;font-weight:700;color:#94A3B8;letter-spacing:.5px;margin-bottom:8px">BELANJAAN ANDA</div><div class="cdlist"></div></div>
        <div style="width:200px;padding:14px 14px 14px 0;display:flex;flex-direction:column;gap:12px">
          <div style="border-radius:18px;padding:20px;background:linear-gradient(135deg,#059669,#047857);box-shadow:0 10px 30px rgba(16,185,129,.35)">
            <div style="font-size:12px;font-weight:700;letter-spacing:1.2px;color:rgba(255,255,255,.8)">TOTAL BELANJA</div>
            <div class="cdtotal tab" style="font-size:30px;font-weight:800;letter-spacing:-1px;margin-top:6px">Rp0</div>
            <div class="cdcount" style="font-size:14px;color:rgba(255,255,255,.8);margin-top:2px">0 barang</div></div>
          <div style="border-radius:16px;padding:14px;background:#0F172A;border:1px solid #1E293B;font-size:13px;color:#94A3B8;line-height:1.5">Bayar pakai<div style="display:flex;gap:8px;margin-top:8px;color:#F1F5F9">${['qr-code', 'banknote', 'credit-card'].map((x) => `<span style="width:40px;height:40px;border-radius:10px;background:#1E293B;display:grid;place-items:center">${ic(x, 20, '#34D399')}</span>`).join('')}</div></div>
          <div style="margin-top:auto;text-align:center;font-size:12px;color:#94A3B8">Terima kasih sudah berbelanja 🙏</div></div></div></div></div></div>`);
  DEV.prepend(tab);
  gsap.set(tab, { autoAlpha: 0 });
  tl.fromTo(tab, { autoAlpha: 0, x: 420, rotationY: -35, transformPerspective: 1600 }, { autoAlpha: 1, x: 0, rotationY: 0, duration: 0.7, ease: 'power3.out' }, s - 0.1);
  sfx(s, 'swish');
  const list = $('.cdlist', tab);
  order.forEach(([, k], i) => {
    const p = P[k];
    const row = el(`<div style="display:flex;align-items:center;gap:10px;padding:6px 8px;border-radius:12px;margin-bottom:4px;position:relative">
      <div class="hlbg" style="position:absolute;inset:0;border-radius:12px;background:rgba(16,185,129,.22);border:1px solid rgba(52,211,153,.5)"></div>
      <div style="position:relative;width:38px;height:38px;border-radius:10px;background:${p.bg};display:grid;place-items:center;font-size:22px;font-family:'Noto Color Emoji'">${p.emo}</div>
      <div style="position:relative;flex:1;min-width:0"><div style="font-size:13.5px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${p.name}</div><div style="font-size:11.5px;color:#94A3B8">1 × ${rp(p.price)}</div></div>
      <div class="tab" style="position:relative;font-size:14px;font-weight:700">${rp(p.price)}</div></div>`);
    list.append(row);
    gsap.set(row, { autoAlpha: 0 });
    const t = times[i] + 0.28;
    tl.fromTo(row, { autoAlpha: 0, x: -40 }, { autoAlpha: 1, x: 0, duration: 0.35, ease: 'power3.out' }, t)
      .fromTo($('.hlbg', row), { opacity: 1 }, { opacity: 0, duration: 0.9, immediateRender: false }, t + 0.1);
    // data beam from phone to the customer display
    const a = stageXY(pos, i % 2 ? 265 : 93, i < 2 ? 200 : 436), b = { x: 420, y: 740 + i * 66 };
    const dot = ov(el(`<div class="ov" style="width:22px;height:22px;margin:-11px;border-radius:50%;background:#6EE7B7;box-shadow:0 0 24px 8px rgba(52,211,153,.7)"></div>`), a.x, a.y);
    tl.fromTo(dot, { autoAlpha: 1, x: 0, y: 0, scale: 0.4 }, { x: b.x - a.x, y: b.y - a.y, scale: 1, duration: 0.28, ease: 'power2.in' }, times[i] + 0.02).to(dot, { autoAlpha: 0, scale: 2.5, duration: 0.15 }, times[i] + 0.3);
    sfx(t, 'blip');
  });
  steps($('.cdcount', tab), cart.map(([t, c]) => [t + 0.28, `${c} barang`]).concat([[0, '0 barang']]).sort((x, y) => x[0] - y[0]));
  at((t) => {
    let v = 0, from = 0, t0 = -1;
    for (const [tt, , vv] of cart) if (t >= tt + 0.28) { from = v; v = vv; t0 = tt + 0.28; }
    const k = t0 < 0 ? 0 : from + (v - from) * prog(t, t0, 0.35, 'power2.out');
    $('.cdtotal', tab).textContent = rp(Math.round(k));
  });
  tl.to(tab, { x: 800, rotationY: 30, autoAlpha: 0, duration: 0.5, ease: 'power3.in' }, s + FLEN - 0.25);
}
