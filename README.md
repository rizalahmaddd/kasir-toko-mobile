# Kasir Toko Mobile

Aplikasi kasir Flutter untuk HP dan tablet, client dari REST API v1 [Kasir Toko (web-pos)](../web-pos). Dokumentasi API ada di `/docs/api` pada server toko.

## Fitur (fase 1: kasir inti)

- Login dengan akun web (username/email/HP + password), alamat server diisi di layar login.
- Buka shift dengan modal awal, kas masuk/keluar, tutup shift dengan hitung selisih uang laci.
- Layar kasir: katalog per kategori, cari nama/SKU/barcode, scan kamera, scanner USB/Bluetooth (langsung terbaca tanpa fokus ke kolom), tekan lama produk untuk isi jumlah desimal.
- Keranjang: jumlah, diskon per barang & transaksi (kalau punya izin `pos.discount`), catatan, pelanggan (cari/tambah cepat), pajak.
- Pembayaran tunai (nominal cepat + kembalian), QRIS bernominal, transfer, kartu, bayar campuran, kasbon.
- Transaksi tertunda, kompatibel dengan kasir web (ditunda di web bisa dilanjutkan di app, dan sebaliknya).
- Riwayat transaksi: filter tanggal/status, cari, detail, struk (bagikan/WhatsApp), pembatalan.
- Layout tablet: katalog dan keranjang berdampingan; HP: katalog dengan bar keranjang di bawah.

## Perilaku penting

- Keranjang disimpan di perangkat dan disinkronkan ulang harga/stoknya saat app dibuka lagi.
- Tiap keranjang punya `client_uuid`; menekan bayar ulang setelah koneksi putus tidak membuat transaksi dobel.
- Total dihitung dengan rumus yang sama dengan `App\Services\Pos\CartCalculator`. Kalau server menolak (`price_changed`, `insufficient_stock`, `unavailable`), keranjang diperbarui otomatis dan kasir memeriksa ulang.
- Font Inter dibundel, jadi app tetap rapi di jaringan toko tanpa internet.

## Menjalankan

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

`API_BASE_URL` hanya nilai awal; alamat server bisa diganti di layar login.

Server lokal lewat HTTP diizinkan (`usesCleartextTraffic` di Android, ATS di iOS) karena umumnya server toko ada di LAN.

## Test

```bash
flutter test                                              # unit + widget
E2E_SERVER=http://127.0.0.1:8000 flutter test test/e2e    # alur kasir ke API sungguhan
```

Test e2e membuka shift dan mencatat penjualan, jadi arahkan ke database percobaan, bukan produksi.

## Struktur

```
lib/
  core/       config server, HTTP client (dio), error API, theme, widget bersama
  features/
    auth/     login, sesi (token di secure storage)
    pos/      katalog, keranjang, pembayaran, transaksi tertunda
    shift/    shift kasir
    sales/    riwayat, detail, struk
    home/     navigasi, akun
```
