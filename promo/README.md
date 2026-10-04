# Video Promo Kasir Toko (60 detik, portrait)

Motion graphics 1080×1920 @30fps untuk promosi aplikasi, dengan UI yang direplikasi dari kode Flutter
(`lib/core/theme`, `lib/features/pos/...`): tema gelap slate/emerald, font Inter, ikon Lucide.

Hasil akhir: **`kasir-toko-promo.mp4`** (H.264 + AAC).

## Isi video
| Waktu | Adegan |
|---|---|
| 0:00–0:05 | Hook "Masih ribet nyatat jualan pakai buku?" → logo Kasir Toko |
| 0:05–0:50 | 12 fitur unggulan (masing-masing 3,75 detik / 2 bar musik): offline, QRIS, struk Bluetooth, layar pelanggan, tunda transaksi, kasbon, cek laci shift, laba otomatis, preset jenis toko, stok fleksibel, hak akses kasir, multi perangkat |
| 0:50–1:00 | Rekap 12 fitur → logo, CTA "Coba Gratis Sekarang", WhatsApp **0857-7777-5477**, kasirtoko.biz.id |

Nomor 0857-7777-5477 tampil di pojok kanan atas di setiap frame.

## Membuat ulang
```bash
cd promo
npm install                 # gsap, lucide-static, @fontsource-variable/inter
node build-icons.js         # inline ikon Lucide → icons.js
node dump-sfx.js            # daftar event SFX dari timeline → sfx.json
pip install numpy scipy && python3 music.py   # musik 128 BPM + SFX → audio.wav
node render.js 4 30         # render frame (Playwright/Chromium) → kasir-toko-promo.mp4
```
Pratinjau frame tertentu: `node preview.js 6.0 12.5` → `shots/`.

## Struktur
- `index.html`, `styles.css` — panggung & replika widget aplikasi
- `lib.js` — helper timeline (GSAP, di-seek per frame secara deterministik) & builder UI
- `scenes.js`, `scenes2.js` — intro, 12 adegan fitur, outro
- `music.py` — sintesis musik & efek suara (tanpa aset berlisensi)
