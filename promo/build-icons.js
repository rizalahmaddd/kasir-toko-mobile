// Inlines the Lucide icons used by the video (same icon set the app uses via lucide_icons_flutter).
const fs = require('fs');
const names = `store shopping-cart layout-dashboard receipt-text package layout-grid search clock sliders-horizontal scan-barcode sun moon
shopping-bag chevron-right chevron-left plus minus check check-check trash-2 triangle-alert wifi wifi-off cloud-off cloud-check cloud-upload
refresh-cw zap zap-off qr-code banknote landmark credit-card shield-check circle-check printer bluetooth message-circle monitor tablet
laptop smartphone pause play user users hand-coins history bell bell-ring calendar-clock wallet arrow-up-right arrow-down-left arrow-left
chart-column-increasing trending-up shopping-basket coffee utensils-crossed shirt wrench hammer pill croissant lock lock-keyhole
eye-off eye x signal battery-full cloud sparkles truck boxes receipt file-text percent rocket hash user-round circle-x ban
book-open calculator notebook-pen menu x-circle signal-high battery-medium arrow-right badge-check store map-pin house
chart-line chart-pie square-pen package-plus package-check timer gauge crown key-round lock-open log-out banknote-arrow-down
hand-helping heart-handshake phone phone-call globe tag qr-code info circle-alert ellipsis-vertical calendar list-checks`.split(/\s+/).filter(Boolean);
const out = {};
for (const n of new Set(names)) {
  const p = `node_modules/lucide-static/icons/${n}.svg`;
  if (!fs.existsSync(p)) { console.warn('missing', n); continue; }
  const svg = fs.readFileSync(p, 'utf8');
  out[n] = svg.slice(svg.indexOf('>', svg.indexOf('<svg')) + 1, svg.lastIndexOf('</svg>')).replace(/\s+/g, ' ').trim();
}
fs.writeFileSync('icons.js', 'window.ICONS=' + JSON.stringify(out) + ';\n');
console.log(Object.keys(out).length, 'icons');
