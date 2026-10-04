// Renders index.html frame-by-frame into kasir-toko-promo.mp4 (1080x1920, 30fps, with audio.wav).
// Usage: node render.js [workers=4] [fps=30] [from=0] [to=DURATION]
const { chromium } = require('playwright');
const { spawn, execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const WORKERS = +(process.argv[2] || 4);
const FPS = +(process.argv[3] || 30);
const EXE = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const OUT = path.join(__dirname, 'out');
fs.mkdirSync(OUT, { recursive: true });

async function renderRange(id, f0, f1) {
  const browser = await chromium.launch({ executablePath: EXE });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  await page.goto('file://' + path.join(__dirname, 'index.html'));
  await page.waitForFunction(() => window.READY === true, null, { timeout: 60000 });
  const seg = path.join(OUT, `seg${id}.mp4`);
  const ff = spawn('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '15', '-pix_fmt', 'yuv420p', seg], { stdio: ['pipe', 'inherit', 'inherit'] });
  // walk forward from 0 so every tween records its start values exactly as in a straight playthrough
  for (let t = 0; t < f0 / FPS; t += 0.5) await page.evaluate((t) => window.seek(t), t);
  const start = Date.now();
  for (let f = f0; f < f1; f++) {
    await page.evaluate((t) => window.seek(t), f / FPS);
    const buf = await page.screenshot({ type: 'jpeg', quality: 95 });
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
    if ((f - f0) % 60 === 0) console.log(`[w${id}] frame ${f}/${f1} ${((Date.now() - start) / Math.max(1, f - f0)).toFixed(0)}ms/f`);
  }
  ff.stdin.end();
  await new Promise((r) => ff.on('close', r));
  await browser.close();
  return seg;
}

(async () => {
  const total = Math.round(60 * FPS);
  const per = Math.ceil(total / WORKERS);
  const segs = await Promise.all(Array.from({ length: WORKERS }, (_, i) => renderRange(i, i * per, Math.min(total, (i + 1) * per))));
  fs.writeFileSync(path.join(OUT, 'list.txt'), segs.map((s) => `file '${s}'`).join('\n'));
  const final = path.join(__dirname, 'kasir-toko-promo.mp4');
  execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', path.join(OUT, 'list.txt'), '-i', path.join(__dirname, 'audio.wav'),
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.2',
    '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', final], { stdio: 'inherit' });
  console.log('done →', final);
})();
