const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  await p.goto('file://' + __dirname + '/index.html');
  await p.waitForFunction(() => window.READY === true);
  const d = await p.evaluate(() => ({ sfx: window.SFX, timing: window.TIMING, duration: window.DURATION }));
  require('fs').writeFileSync(__dirname + '/sfx.json', JSON.stringify(d, null, 1));
  console.log(d.sfx.length, 'events', [...new Set(d.sfx.map((s) => s.type))].join(' '));
  await b.close();
})();
