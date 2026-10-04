// Usage: node preview.js 1.0 5.7 9.9 ... → writes shots/t_XX.png
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  const errs = [];
  p.on('pageerror', (e) => errs.push(e.message));
  p.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errs.push(m.text()); });
  await p.goto('file://' + __dirname + '/index.html');
  await p.waitForFunction(() => window.READY === true, null, { timeout: 30000 }).catch(() => console.log('NOT READY'));
  if (errs.length) console.log('ERRORS:', errs.join('\n'));
  require('fs').mkdirSync(__dirname + '/shots', { recursive: true });
  for (const t of process.argv.slice(2).map(Number)) {
    await p.evaluate((t) => window.seek(t), t);
    await p.screenshot({ path: `${__dirname}/shots/t_${t.toFixed(2)}.png` });
  }
  await b.close();
})();
