# Kasir Toko Mobile

Aplikasi kasir Flutter untuk HP dan tablet, client dari REST API v1 [Kasir Toko (web-pos)](../kasir-toko). Dokumentasi API tersedia di `/docs/api` pada server web.

- **Package ID / Application ID (Android)**: `com.jagodev.kasirtoko`
- **Bundle Identifier (iOS)**: `com.jagodev.kasirtoko`

Satu build dapat digunakan dalam dua mode:

- **Layanan SaaS (hosted)**: Semua toko menggunakan server cloud terpusat (`https://kasirtoko.biz.id`). Field server disembunyikan dan toko baru dapat mendaftar langsung dari aplikasi.
- **Server sendiri (self-hosted)**: Toko menjalankan aplikasi web di LAN atau VPS sendiri, alamat server diisi langsung di layar login.

---

## Fitur Utama

- **Autentikasi & Akun**:
  - Login username/email/nomor HP + password atau OTP WhatsApp.
  - Social Login: **Google Sign-In** dan **Sign in with Apple**.
  - Pendaftaran toko baru (pada build hosted).
  - Profil, ganti password, opsi keluar dari seluruh perangkat, dan penghapusan akun mandiri (kepatuhan Play Store / App Store).
- **Layar Kasir**:
  - Katalog produk dengan filter kategori dan pilihan kepadatan kartu (standar / kompak).
  - Pencarian nama, SKU, dan barcode.
  - Pemindai barcode kamera, barcode scanner USB & Bluetooth (otomatis terbaca tanpa perlu fokus ke input).
  - Kuantitas desimal untuk barang timbangan/eceran.
  - Diskon per item dan diskon transaksi (berdasarkan izin `pos.discount`).
  - Catatan transaksi, pilihan/tambah cepat pelanggan, dan perhitungan pajak.
- **Pembayaran**:
  - Tunai (saran pecahan uang cepat & hitung kembalian).
  - **QRIS Dinamis**: Tampilan QRIS bernominal otomatis dengan fitur **layar tetap menyala (wakelock)** dan **kecerahan layar otomatis maksimal** agar mudah dipindai pelanggan.
  - Transfer bank, kartu debit/kredit, pembayaran campuran (split payment), dan kasbon/piutang pelanggan.
- **Transaksi Tertunda**: Simpan keranjang sementara dan lanjutkan kapan saja; kompatibel penuh dengan keranjang tertunda di kasir web.
- **Shift Kasir**: Buka shift dengan modal awal, pencatatan kas masuk/keluar, tutup shift dengan hitung selisih uang laci, serta riwayat shift.
- **Riwayat & Struk**: Filter transaksi, rincian pembayaran, pembatalan (void), cetak struk via printer thermal Bluetooth (ESC/POS 58/80mm), atau bagikan via WhatsApp.
- **Back Office & Manajemen**:
  - Dashboard performa toko dengan status sinkronisasi offline dan peringatan shift.
  - Manajemen produk (foto, barcode, harga, HPP, stok minimum), kategori, dan mutasi kartu stok.
  - Manajemen pelanggan, piutang (kasbon), log aktivitas, dan notifikasi stok/sistem.
  - Laporan penjualan komprehensif.
  - Perlindungan **Fitur Pro**: Dialog interaktif upgrade paket langganan bagi toko di luar paket Pro/Trial.
- **Mode Offline & Sinkronisasi**:
  - Kasir tetap dapat bertransaksi meski jaringan internet/server terputus.
  - Transaksi offline masuk antrean aman dan disinkronkan otomatis saat koneksi kembali.
- **Desain Responsif**:
  - Tampilan khusus tablet (katalog dan keranjang belanja berdampingan).
  - Tampilan ponsel (katalog dengan bottom sheet keranjang belanja).

---

## Perilaku Penting & Keamanan Data

- **Penyimpanan Lokal Keranjang**: Keranjang belanja tersimpan aman di perangkat dan otomatis disinkronkan kembali harga serta stoknya saat aplikasi dibuka ulang.
- **Idempotensi Transaksi**: Setiap keranjang memiliki `client_uuid`, sehingga penekanan tombol bayar berulang saat jaringan lambat atau proses sinkronisasi offline tidak akan menghasilkan transaksi ganda.
- **Validasi Harga & Stok Server**: Total transaksi dihitung dengan algoritma yang identik dengan server (`CartCalculator`). Jika terdapat perubahan harga atau stok tidak mencukupi, aplikasi otomatis memperbarui keranjang dan meminta kasir memverifikasi ulang.
- **Multi-tenant & Isolasi Data**:
  - Informasi toko (`tenant`), nama, paket, dan sisa masa aktif diperoleh via endpoint `auth/me`.
  - Jika toko dinonaktifkan atau masa aktif langganan habis, respons `402 Payment Required` akan mengarahkan aplikasi ke layar informasi perpanjangan langganan.
  - Cache offline (katalog, pengaturan kasir, dsb.) diisolasi per toko. Jika kasir berganti akun/toko pada perangkat yang sama, data toko sebelumnya otomatis dibersihkan demi privasi.
- **Tipografi**: Font Inter dibundel secara lokal agar UI tetap konsisten dan rapi tanpa ketergantungan koneksi internet.

---

## Menjalankan & Membangun Aplikasi

### 1. Pengembangan Lokal (Self-Hosted)
Alamat server dapat diganti langsung pada halaman login aplikasi:
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

### 2. Build Produksi SaaS (Hosted)
Mengunci endpoint server ke domain produksi (`https://kasirtoko.biz.id`), menyembunyikan konfigurasi URL di halaman login, dan membuka formulir pendaftaran:
```bash
flutter build apk --release --dart-define=HOSTED=true
```

Untuk membagi file APK per arsitektur CPU (split APK):
```bash
flutter build apk --release --split-per-abi --dart-define=HOSTED=true
```

---

## CI/CD & Rilis Otomatis (GitHub Actions)

Aplikasi telah dilengkapi workflow otomatisasi rilis pada [`.github/workflows/release-android.yml`](.github/workflows/release-android.yml):

- **Pemicu (Trigger)**: Otomatis berjalan saat push git tag `v*` (contoh: `v1.0.0`, `v1.0.1+2`) atau dijalankan manual (`workflow_dispatch`).
- **Target Environment**: `production` (kredensial signing aman menggunakan GitHub Actions Secrets).
- **Hasil Rilis (AAB & Split APK)**:
  - `kasirtoko-${TAG}.aab`: **Android App Bundle resmi** siap upload langsung ke Google Play Console.
  - `kasirtoko-${TAG}-arm64-v8a.apk`: Mayoritas smartphone Android modern (64-bit).
  - `kasirtoko-${TAG}-armeabi-v7a.apk`: Smartphone Android generasi lama (32-bit).
  - `kasirtoko-${TAG}-x86_64.apk`: Emulator Android dan perangkat berbasis Intel/AMD.
- **Aset Tambahan**: File hash SHA-256 (`checksums.txt`) untuk validasi keaslian file rilis.
- **Distribusi**: Otomatis membuat GitHub Release baru serta mengunggah file ke tab Artifacts GitHub Actions.

---

## Pengujian (Testing)

```bash
# Menjalankan unit dan widget test
flutter test --dart-define=HOSTED=true

# Menjalankan test e2e terhadap server API sungguhan
E2E_SERVER=http://127.0.0.1:8000 flutter test test/e2e
```

*Catatan: Pengujian e2e melakukan login sebagai `kasir` dan `owner` (password default: `password`), membuka shift, dan melakukan checkout transaksi. Gunakan database testing (`php artisan migrate:fresh --seed`), bukan database produksi.*

---

## Materi Promosi & Video Vertikal (`promo/`)

Repositori memuat generator dan aset video promosi vertikal 60 detik (format 9:16 / 1080x1920) siap pakai untuk kampanye media sosial (TikTok, Instagram Reels, YouTube Shorts):

- **Visual & Animasi**: Dibangun menggunakan HTML, GSAP, dan di-render per frame menggunakan Playwright, menampilkan tema dark emerald aplikasi dan 12 fitur unggulan kasir.
- **Audio & Musik**: Soundtrack sintetis 128 BPM dengan efek suara (SFX) yang tersinkronisasi presisi per adegan.
- **File Video Jadi**: `promo/kasir-toko-promo.mp4` siap dipublikasikan.
- **Preview & Re-render**:
  ```bash
  cd promo
  npm install
  npm run preview  # Menjalankan preview lokal interaktif di browser
  npm run render   # Merender ulang video MP4 frame-by-frame
  ```

---

## Struktur Direktori

```
lib/
  core/           Konfigurasi server (hosted mode), HTTP client (Dio), tema, cache offline, widget bersama
  features/
    auth/         Autentikasi (password, social auth Google/Apple), register toko, status langganan
    pos/          Katalog, keranjang, pembayaran QRIS/tunai/split, transaksi tertunda
    shift/        Buka/tutup shift kasir dan rekap laci uang
    sales/        Riwayat transaksi, detail penjualan, dan cetak struk
    offline/      Snapshot katalog offline dan antrean transaksi tertunda
    printing/     Integrasi printer thermal Bluetooth (ESC/POS)
    products/     Manajemen produk, kategori, dan kartu stok
    customers/    Data pelanggan toko
    receivables/  Manajemen kasbon/piutang penjualan
    reports/      Laporan omzet, laba kotor, dan riwayat aktivitas
    dashboard/    Ringkasan performa penjualan dan status operasional
    notifications/Pusat notifikasi dan pencarian global
    home/         Navigasi bottom bar, drawer menu, dan akun toko
promo/            Generator dan aset video promosi vertikal 60s (HTML/GSAP/Playwright + soundtrack)
```
