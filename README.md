# Kasir Toko Mobile

Aplikasi kasir Flutter untuk HP dan tablet, client dari REST API v1 [Kasir Toko (web-pos)](../web-pos). Dokumentasi API ada di `/docs/api` pada server.

Satu build bisa dipakai dua cara:

- **Layanan SaaS (hosted)**: semua toko memakai satu server yang alamatnya dikunci di build. Toko baru bisa mendaftar langsung dari aplikasi.
- **Server sendiri**: toko menjalankan web-pos di LAN atau servernya sendiri, dan alamat server diisi di layar login.

## Fitur

- **Akun**: login username/email/HP + password atau OTP WhatsApp, daftar toko baru (build hosted), ganti profil & password, keluar dari semua perangkat.
- **Kasir**: katalog per kategori, cari nama/SKU/barcode, scan kamera, scanner USB/Bluetooth (langsung terbaca tanpa fokus ke kolom), jumlah desimal, diskon per barang & transaksi (kalau punya izin `pos.discount`), catatan, pelanggan (cari/tambah cepat), pajak.
- **Pembayaran**: tunai (nominal cepat + kembalian), QRIS bernominal, transfer, kartu, bayar campuran, kasbon.
- **Transaksi tertunda**, kompatibel dengan kasir web (ditunda di web bisa dilanjutkan di app, dan sebaliknya).
- **Shift**: buka dengan modal awal, kas masuk/keluar, tutup dengan hitung selisih uang laci, riwayat shift.
- **Riwayat transaksi**: filter, detail, struk (bagikan/WhatsApp/cetak), pembatalan.
- **Back office**: dashboard, produk (termasuk foto), kategori, stok & kartu stok, pelanggan, piutang (kasbon), laporan penjualan, log aktivitas, notifikasi, pencarian global. Menu tampil sesuai izin dan sakelar fitur dari `auth/me`.
- **Printer thermal Bluetooth** (ESC/POS) untuk struk dan rekap shift.
- **Mode offline**: kasir tetap bisa berjualan saat server tidak terjangkau. Transaksi masuk antrean dan dikirim otomatis begitu koneksi kembali.
- **Layout tablet**: katalog dan keranjang berdampingan. Di HP, katalog tampil dengan bar keranjang di bawah.

## Perilaku penting

- Keranjang disimpan di perangkat dan disinkronkan ulang harga/stoknya saat app dibuka lagi.
- Tiap keranjang punya `client_uuid`, jadi menekan bayar ulang setelah koneksi putus (atau sinkronisasi antrean offline) tidak membuat transaksi dobel.
- Total dihitung dengan rumus yang sama dengan `App\Services\Pos\CartCalculator`. Kalau server menolak (`price_changed`, `insufficient_stock`, `unavailable`), keranjang diperbarui otomatis dan kasir memeriksa ulang.
- Font Inter dibundel, jadi app tetap rapi di jaringan toko tanpa internet.

### Multi-tenant

- `auth/me` membawa data toko (`tenant`): nama, paket, dan masa aktif. Data ini tampil di layar **Akun**.
- Toko yang di-suspend atau habis masa aktifnya mendapat jawaban `402` dengan `reason`. App lalu pindah ke layar **"Toko belum bisa dipakai"** yang punya tombol *Periksa lagi* dan *Keluar*. Antrean offline berhenti mengirim (tidak ditandai gagal) sampai toko aktif lagi.
- Cache offline (katalog, konfigurasi kasir, dll.) diberi tanda server + toko, jadi toko lain yang login di HP yang sama tidak pernah membaca data toko sebelumnya. Saat login ke toko yang berbeda, keranjang dan cache lama dihapus. Transaksi offline yang belum terkirim tetap disimpan dan baru dikirim saat kasir pemiliknya login lagi.

## Menjalankan

Server sendiri (alamat bisa diganti di layar login, `API_BASE_URL` hanya nilai awal):

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Build layanan SaaS (alamat server dikunci ke `https://kasirtoko.biz.id`, field server disembunyikan, tombol daftar toko muncul):

```bash
flutter build apk --release --dart-define=HOSTED=true
```

Tambahkan `--dart-define=API_BASE_URL=...` untuk mengarahkan build hosted ke server lain, misalnya staging.

Server lokal lewat HTTP diizinkan (`usesCleartextTraffic` di Android, ATS di iOS) karena server toko yang dijalankan sendiri umumnya ada di LAN. Build hosted sebaiknya memakai HTTPS.

## Test

```bash
flutter test                                              # unit + widget
E2E_SERVER=http://127.0.0.1:8000 flutter test test/e2e    # alur kasir & back office ke API sungguhan
```

Test e2e login sebagai `kasir` dan `superadmin` (password `password`; bisa diganti lewat `E2E_LOGIN`, `E2E_ADMIN`, `E2E_PASSWORD`), membuka shift, dan mencatat penjualan, jadi arahkan ke database percobaan seperti hasil `php artisan migrate:fresh --seed` di web-pos, bukan produksi.

## Struktur

```
lib/
  core/       config server (mode hosted), HTTP client (dio), error API, cache offline, theme, widget bersama
  features/
    auth/          login, daftar toko, layar toko diblokir, sesi (token di secure storage)
    pos/           katalog, keranjang, pembayaran, transaksi tertunda
    shift/         shift kasir
    sales/         riwayat, detail, struk
    offline/       snapshot katalog & antrean transaksi offline
    printing/      printer thermal Bluetooth, tata letak struk
    products/      produk, kategori, stok
    customers/     pelanggan
    receivables/   piutang (kasbon)
    reports/       laporan penjualan, log aktivitas
    dashboard/     ringkasan
    notifications/ notifikasi & pencarian global
    home/          navigasi, menu, akun
```
