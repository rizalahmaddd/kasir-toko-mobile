/* Helpers + app UI builders for the Kasir Toko promo. Everything is deterministic: the timeline is
   seeked frame by frame, and `hooks` derive DOM state (text, toggles) purely from the current time. */

const BEAT = 60 / 128;
const FEAT0 = 12 * BEAT;          // 5.625s — first feature starts on the drop
const FLEN = 8 * BEAT;            // 3.75s — two bars per feature
const OUT0 = FEAT0 + 12 * FLEN;   // 50.625s — outro
const DURATION = 60;

const tl = gsap.timeline({ paused: true });
const hooks = [];
const SFX = [];
const at = (fn) => hooks.push(fn);
const sfx = (t, type, extra = {}) => SFX.push({ t: +t.toFixed(4), type, ...extra });

window.seek = (t) => {
  tl.seek(t, true);
  for (const h of hooks) h(t);
};
window.SFX = SFX;
window.DURATION = DURATION;
window.TIMING = { BEAT, FEAT0, FLEN, OUT0 };

const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];
function el(html) {
  const t = document.createElement('template');
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
}
const ic = (name, size = 20, color = 'currentColor', sw = 2) =>
  `<svg class="ic" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round">${ICONS[name] || ''}</svg>`;
const dots = (n) => Math.round(Math.abs(n)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const rp = (n) => (n < 0 ? '-' : '') + 'Rp' + dots(n);
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const E = (name) => gsap.parseEase(name);
const prog = (t, t0, dur, ease = 'none') => E(ease)(clamp((t - t0) / dur));

function rng(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let r = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

/* ---------- time-driven DOM hooks ---------- */
function counter(node, t0, dur, from, to, fmt = rp, ease = 'power2.out') {
  at((t) => { node.textContent = fmt(Math.round(from + (to - from) * prog(t, t0, dur, ease))); });
}
function steps(node, list, fmt = (v) => v) {
  // list: [[time, value], ...] — shows the latest value whose time has passed.
  at((t) => {
    let v = list[0][1];
    for (const [tt, vv] of list) if (t >= tt) v = vv;
    const s = fmt(v);
    if (node.textContent !== s) node.textContent = s;
  });
}
function typeText(node, text, t0, cps = 14, caretNode = null) {
  at((t) => {
    const n = clamp(Math.floor((t - t0) * cps), 0, text.length);
    node.textContent = t < t0 ? '' : text.slice(0, n);
    if (caretNode) caretNode.style.opacity = Math.floor(t * 2.4) % 2 ? 0.15 : 1;
  });
}
function toggle(node, tOn, tOff = Infinity, prop = 'display', on = '', off = 'none') {
  at((t) => { node.style[prop] = t >= tOn && t < tOff ? on : off; });
}
function typeSfx(t0, text, cps) {
  for (let i = 0; i < text.length; i++) sfx(t0 + i / cps, 'key');
}

/* ---------- tap feedback ---------- */
function tap(container, x, y, t, sound = 'tap') {
  const dot = el(`<div class="tapdot" style="left:${x}px;top:${y}px"></div>`);
  const rip = el(`<div class="ripple" style="left:${x}px;top:${y}px"></div>`);
  container.append(dot, rip);
  tl.fromTo(dot, { opacity: 0, scale: 1.4 }, { opacity: 1, scale: 1, duration: 0.14, ease: 'power2.out' }, t - 0.16)
    .to(dot, { scale: 0.78, duration: 0.07, ease: 'power2.in' }, t - 0.03)
    .to(dot, { opacity: 0, scale: 1.1, duration: 0.22, ease: 'power1.out' }, t + 0.08)
    .fromTo(rip, { opacity: 0.95, scale: 0.15 }, { opacity: 0, scale: 1.25, duration: 0.5, ease: 'power2.out', immediateRender: false }, t);
  if (sound) sfx(t, sound);
}
function press(node, t, s = 0.95) {
  tl.to(node, { scale: s, duration: 0.07, ease: 'power2.out' }, t - 0.02).to(node, { scale: 1, duration: 0.3, ease: 'back.out(3)' }, t + 0.06);
}

/* ---------- devices ---------- */
function statusBar() {
  return `<div class="statusbar"><span class="tab">09:41</span><div class="cam"></div>
    <div class="rt">${ic('signal', 15, '#F1F5F9', 2.4)}
      <div class="sb-wifi"><span class="wifi-on">${ic('wifi', 15, '#F1F5F9', 2.4)}</span><span class="wifi-off" style="opacity:0">${ic('wifi-off', 15, '#F43F5E', 2.4)}</span></div>
      <span style="display:flex;align-items:center;gap:2px;font-size:11.5px">${ic('battery-full', 19, '#F1F5F9', 2)}</span></div></div>`;
}
function makePhone(id) {
  const p = el(`<div class="device" id="${id}"><div class="phone"><div class="viewport">${statusBar()}</div></div></div>`);
  return p;
}
const vp = (phone) => $('.viewport', phone);
function phonePos(cx, top, s) { return { x: cx - 192 * s, y: top, scale: s }; }

/* ---------- data ---------- */
const P = {
  kopi:   { name: 'Kopi Susu Gula Aren', sku: 'KP-001', price: 18000, stock: '24 cup', emo: '☕', bg: 'radial-gradient(circle at 50% 40%, #7c4a2a, #3b2316)' },
  mie:    { name: 'Indomie Goreng Original', sku: 'IDM-GR', price: 3500, stock: '118 pcs', emo: '🍜', bg: 'radial-gradient(circle at 50% 40%, #b45309, #5c2a07)' },
  teh:    { name: 'Teh Botol Sosro 450ml', sku: 'TB-450', price: 5000, stock: '48 btl', emo: '🧋', bg: 'radial-gradient(circle at 50% 40%, #a16207, #422006)' },
  roti:   { name: 'Roti Tawar Gandum', sku: 'RT-GDM', price: 16500, stock: '3 pcs', low: true, emo: '🍞', bg: 'radial-gradient(circle at 50% 40%, #c2410c, #4a1d0a)' },
  telur:  { name: 'Telur Ayam Negeri', sku: 'TLR-KG', price: 28000, stock: '9 kg', emo: '🥚', bg: 'radial-gradient(circle at 50% 40%, #94a3b8, #334155)' },
  beras:  { name: 'Beras Premium 5kg', sku: 'BRS-5', price: 72000, stock: '15 sak', emo: '🍚', bg: 'radial-gradient(circle at 50% 40%, #64748b, #1e293b)' },
  air:    { name: 'Air Mineral 600ml', sku: 'AM-600', price: 4000, stock: '96 btl', emo: '💧', bg: 'radial-gradient(circle at 50% 40%, #0369a1, #0c2a44)' },
  ksb:    { name: 'Kopi Susu Botol 250ml', sku: 'KSB-250', price: 12000, stock: '0 btl', neg: true, emo: '🥛', bg: 'radial-gradient(circle at 50% 40%, #92400e, #2b1405)' },
  uht:    { name: 'Susu UHT Cokelat 200ml', sku: 'UHT-200', price: 6500, stock: '36 kotak', emo: '🍫', bg: 'radial-gradient(circle at 50% 40%, #713f12, #2a1405)' },
  donat:  { name: 'Donat Gula Halus', sku: 'DNT-01', price: 4000, stock: '20 pcs', emo: '🍩', bg: 'radial-gradient(circle at 50% 40%, #be185d, #4a0d27)' },
};

/* ---------- app UI builders (HTML strings) ---------- */
function productCard(p, key) {
  let badge = '';
  if (p.neg) badge = `<div class="stockbadge" style="background:var(--rose500)">${ic('triangle-alert', 10, '#fff', 2.5)}Stok 0</div>`;
  else if (p.low) badge = `<div class="stockbadge" style="background:var(--amber500)">${ic('triangle-alert', 10, '#fff', 2.5)}Sisa 3</div>`;
  const stkClass = p.neg ? 'danger' : p.low ? 'warn' : '';
  const stkText = p.neg ? `Stok: ${p.stock}` : p.stock;
  return `<div class="pcard" data-k="${key}">
    <div class="photo" style="background:${p.bg}"><span class="emo">${p.emo}</span>${badge}</div>
    <div class="stepper"><span class="dec"><i class="tr">${ic('trash-2', 13, '#fff', 2.2)}</i><i class="mi" style="display:none">${ic('minus', 13, '#fff', 2.4)}</i></span><span class="q">1</span><span>${ic('plus', 13, '#fff', 2.4)}</span></div>
    <div class="det"><div class="nm">${p.name}</div><div class="sku">${p.sku}</div>
      <div class="bot"><div class="sp col"><div class="price">${rp(p.price)}</div><div class="stk ${stkClass}">${stkText}</div></div>
      <div class="addbtn">${ic('plus', 14, '#CBD5E1', 2.2)}<div class="on">${ic('check', 14, '#fff', 2.6)}</div></div></div></div>
    <div class="sel"></div></div>`;
}
/** Drives a product card's in-cart state from a list of [time, qty]. */
function cardQty(card, list) {
  const sel = $('.sel', card), st = $('.stepper', card), on = $('.addbtn .on', card), q = $('.q', card), tr = $('.tr', card), mi = $('.mi', card);
  at((t) => {
    let v = 0;
    for (const [tt, vv] of list) if (t >= tt) v = vv;
    const o = v > 0 ? 1 : 0;
    sel.style.opacity = o; st.style.opacity = o; on.style.opacity = o;
    q.textContent = v;
    tr.style.display = v <= 1 ? '' : 'none';
    mi.style.display = v > 1 ? '' : 'none';
  });
  for (const [tt, vv] of list) if (vv > 0) tl.fromTo(st, { scale: 0.6 }, { scale: 1, duration: 0.35, ease: 'back.out(3)', immediateRender: false }, tt);
}

function navBar(active = 1, badge = null) {
  const tabs = [['layout-dashboard', 'Beranda'], ['shopping-cart', 'Kasir'], ['receipt-text', 'Transaksi'], ['package', 'Produk'], ['layout-grid', 'Menu']];
  return `<div class="navbar">${tabs.map(([i, l], k) => `<div class="it ${k === active ? 'on' : ''}"><div class="ind">${ic(i, 22, 'currentColor', 2)}${k === 1 && badge !== null ? `<span class="badge navbadge">${badge}</span>` : ''}</div>${l}</div>`).join('')}</div>`;
}
function posHeader(held = 1) {
  return `<div class="pos-head"><div class="shift-pill"><div class="dot8"></div>#24 · Rina</div><div class="sp"></div>
    <div class="iconbtn">${ic('search', 20)}</div>
    <div class="iconbtn clockbtn">${ic('clock', 20)}${held ? `<span class="badge heldbadge">${held}</span>` : ''}</div>
    <div class="iconbtn">${ic('sliders-horizontal', 20)}</div>
    <div class="iconbtn">${ic('scan-barcode', 20)}</div>
    <div class="iconbtn">${ic('sun', 20)}</div></div>`;
}
function catChips(active = 0, names = ['Minuman', 'Makanan', 'Sembako', 'Snack', 'Rokok']) {
  return `<div class="cats"><div class="cat ${active === 0 ? 'on' : ''}">${ic('layout-grid', 15, active === 0 ? '#fff' : '#94A3B8')}Semua</div>${names.map((n, i) => `<div class="cat ${active === i + 1 ? 'on' : ''}">${n}</div>`).join('')}</div>`;
}
function cartBar() {
  return `<div class="cartbar-wrap"><div class="cartbar"><div class="bagbox">${ic('shopping-bag', 20, '#fff')}</div>
    <div class="sp"><div class="t1 cb-count">1 barang</div><div class="t2">Buka keranjang untuk checkout</div></div>
    <div><div class="amt cb-total">Rp0</div><div class="pay">Bayar${ic('chevron-right', 14, 'rgba(255,255,255,.7)')}</div></div></div></div>`;
}
function posScreen(id, keys, opts = {}) {
  return el(`<div class="screen app" id="${id}"><div class="safe">${posHeader(opts.held ?? 1)}${catChips(opts.cat ?? 0, opts.cats)}
    <div class="grid2">${keys.map((k) => productCard(P[k], k)).join('')}</div></div>${opts.cart === false ? '' : cartBar()}${navBar(1, opts.navBadge ?? null)}</div>`);
}
/** Cart bar: slides in at the first time, then follows [time, count, total]. */
function driveCartBar(scr, list) {
  const wrap = $('.cartbar-wrap', scr);
  tl.fromTo(wrap, { yPercent: 110 }, { yPercent: 0, duration: 0.4, ease: 'back.out(1.4)' }, list[0][0]);
  steps($('.cb-count', scr), list.map(([t, c]) => [t, c]), (c) => `${c} barang`);
  steps($('.cb-total', scr), list.map(([t, , v]) => [t, v]), rp);
  for (const [t] of list.slice(1)) tl.fromTo($('.cartbar', scr), { scale: 1.04 }, { scale: 1, duration: 0.3, ease: 'power2.out', immediateRender: false }, t);
}

function qrSvg(seed = 7, n = 29) {
  const r = rng(seed);
  const m = Array.from({ length: n }, () => Array.from({ length: n }, () => r() > 0.52));
  const finder = (x0, y0) => {
    for (let y = -1; y <= 7; y++) for (let x = -1; x <= 7; x++) {
      const X = x0 + x, Y = y0 + y;
      if (X < 0 || Y < 0 || X >= n || Y >= n) continue;
      const ring = Math.max(Math.abs(x - 3), Math.abs(y - 3));
      m[Y][X] = ring === 3 || ring <= 1;
    }
  };
  finder(0, 0); finder(n - 7, 0); finder(0, n - 7);
  for (let i = 8; i < n - 8; i++) { m[6][i] = i % 2 === 0; m[i][6] = i % 2 === 0; }
  for (let y = -2; y <= 2; y++) for (let x = -2; x <= 2; x++) m[n - 9 + y][n - 9 + x] = Math.max(Math.abs(x), Math.abs(y)) !== 1;
  let d = '';
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (m[y][x]) d += `M${x} ${y}h1v1h-1z`;
  return `<svg viewBox="0 0 ${n} ${n}" width="200" height="200" shape-rendering="crispEdges"><path d="${d}" fill="#000"/></svg>`;
}

function sheetHeader(title, sub = '') {
  return `<div class="handle"></div><div class="sheet-h"><div class="sp"><div class="tt">${title}</div>${sub ? `<div class="st">${sub}</div>` : ''}</div>${ic('x', 22, '#F1F5F9')}</div>`;
}
function moneyField(label, cls = '', focus = true) {
  return `<div class="field ${focus ? 'focus' : ''} ${cls}"><span class="flabel">${label}</span><span style="color:#94A3B8;margin-right:6px">Rp</span><span class="fv tab" style="font-weight:600"></span><span class="caret"></span></div>`;
}
function snack(text, icon = null, iconColor = '#047857') {
  return `<div class="snack">${icon ? ic(icon, 18, iconColor, 2.4) : ''}<span>${text}</span></div>`;
}
/** Shows/hides an element with a quick pop (used for snackbars, dialogs). */
function popIn(node, t, dur = 0.3, from = { y: 20, scale: 0.96 }) {
  tl.fromTo(node, { autoAlpha: 0, ...from }, { autoAlpha: 1, y: 0, scale: 1, duration: dur, ease: 'back.out(1.6)' }, t);
}
function popOut(node, t, dur = 0.22, to = { y: 10 }) {
  tl.to(node, { autoAlpha: 0, ...to, duration: dur, ease: 'power2.in' }, t);
}

/* ---------- marketing overlays ---------- */
function toast(icon, text, color = '#10B981', extraStyle = '') {
  return el(`<div class="ov glass toast" style="${extraStyle}"><div class="ib" style="background:${color}">${ic(icon, 32, '#fff', 2.4)}</div><span>${text}</span></div>`);
}
