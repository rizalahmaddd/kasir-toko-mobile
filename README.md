# Kasir Toko Mobile

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![State Management](https://img.shields.io/badge/State_Management-Riverpod-8A2BE2)](https://riverpod.dev)
[![HTTP Client](https://img.shields.io/badge/HTTP_Client-Dio-00599C)](https://pub.dev/packages/dio)
[![Thermal Printer](https://img.shields.io/badge/Thermal_Printer-ESC%2FPOS-1E88E5?logo=bluetooth&logoColor=white)](https://pub.dev/packages/esc_pos_utils_plus)
[![Tests](https://img.shields.io/badge/Tests-112_passed-success?logo=flutter&logoColor=white)](#-pengujian--kualitas-kode)

Aplikasi kasir (Point of Sale) mobile modern berbasis **Flutter**, dirancang optimal untuk smartphone dan tablet Android maupun iOS. Berfungsi sebagai aplikasi kasir lapangan dan pendamping dari sistem SaaS [**Kasir Toko (Web POS)**](../kasir-toko).

- **Package ID / Application ID (Android)**: `com.jagodev.kasirtoko`
- **Bundle Identifier (iOS)**: `com.jagodev.kasirtoko`

Aplikasi ini mendukung dua mode operasional:
1. **Layanan SaaS (Hosted)**: Terhubung langsung ke cloud terpusat (`https://kasirtoko.biz.id`), pendaftaran toko baru langsung dari aplikasi.
2. **Mandiri (Self-Hosted)**: Toko dapat mengarahkan aplikasi ke server lokal/VPS sendiri dengan mengisi URL server di layar login.

---

## ✨ Fitur Unggulan

### 🛒 Layar Kasir Cepat & Responsif
- **Tata Letak Adaptif**: Tampilan tablet dua kolom (katalog dan keranjang belanja berdampingan) serta tampilan ponsel dengan lembar keranjang (*bottom sheet*).
- **Katalog & Navigasi Cepat**: Pencarian instan nama/SKU/barcode, filter kategori dinamis, dan pilihan kepadatan kartu (standar / kompak).
- **Scanner Barcode Terintegrasi**: Scan instan menggunakan kamera perangkat, barcode scanner USB, atau Bluetooth tanpa perlu memfokuskan kursor.
- **Kalkulasi Fleksibel**: Kuantitas desimal untuk barang timbangan, diskon per item atau diskon transaksi (berdasarkan izin `pos.discount`), dan pajak opsional.
- **Transaksi Tertunda**: Simpan keranjang belanja sementara dan lanjutkan kapan saja (sinkron dengan keranjang kasir web).

### 💳 Pembayaran Lengkap & QRIS Dinamis
- **Metode Pembayaran**: Tunai dengan saran pecahan uang cepat & hitung kembalian, QRIS, transfer bank, kartu debit/kredit, *split payment*, dan kasbon pelanggan.
- **QRIS Auto-Bright & Wakelock**: Tampilan QRIS dinamis bernominal pas dengan fitur **layar tetap menyala (*wakelock*)** dan **kecerahan layar otomatis maksimal** agar mudah dipindai oleh kamera pelanggan.
- **Shift Kasir**: Buka shift dengan modal awal, catat kas masuk/keluar, hitung selisih uang laci saat tutup shift, dan cetak ringkasan shift.

### 📶 Mode Offline & Sinkronisasi Cerdas
- **Transaksi Tanpa Internet**: Kasir tetap dapat melayani penjualan saat koneksi internet atau server backend terputus.
- **Antrean Transaksi Aman**: Penjualan offline otomatis disimpan di perangkat dan disinkronkan ke server secara otomatis begitu koneksi kembali pulih.
- **Isolasi Cache Multi-Tenant**: Cache offline dan data lokal terisolasi ketat per toko; data otomatis dibersihkan saat berganti akun demi keamanan data.

### 🖨️ Cetak Struk Thermal Bluetooth
- **Dukungan ESC/POS**: Kompatibel dengan printer thermal Bluetooth portabel ukuran kertas 58mm dan 80mm.
- **Kirim Struk Digital**: Bagikan bukti pembayaran langsung ke nomor WhatsApp pelanggan dengan satu ketukan.

### 📊 Back Office, Inventori & Laporan
- **Dashboard Ringkasan**: Pantau omzet harian, status shift aktif, dan antrean sinkronisasi offline.
- **Manajemen Produk & Stok**: Kelola foto produk, barcode, harga beli/jual, batas stok minimum, dan kartu mutasi stok.
- **Manajemen Pelanggan & Piutang**: Pencatatan riwayat kasbon/piutang dan pelunasan bertahap.
- **Laporan Penjualan**: Laporan omzet, laba kotor, dan riwayat transaksi lengkap.

### 🔐 Autentikasi Modern & Kepatuhan Store
- **Social Login**: Masuk instan dengan akun Google dan Apple.
- **Login Fleksibel**: Dukungan login kata sandi atau kode OTP via WhatsApp.
- **Kepatuhan Google Play & Apple App Store**: Tombol ganti password, keluar dari semua perangkat, dan fitur **Permintaan Hapus Akun Mandiri**.

---

## 🛡️ Penanganan Kasus Khusus & Keamanan Data

| Skenario | Solusi Sistem |
|---|---|
| Koneksi internet terputus saat transaksi | Sistem beralih ke mode offline; transaksi disimpan lokal dan di-queue untuk auto-sync |
| Tombol bayar ditekan berulang / koneksi tidak stabil | `client_uuid` unik di setiap transaksi menjamin idempotensi (tidak ada transaksi ganda) |
| Harga barang atau ketersediaan stok berubah di server | Algoritma `CartCalculator` memvalidasi ulang keranjang dan memberitahu kasir jika ada selisih |
| Kasir berganti akun toko di perangkat yang sama | Seluruh cache lokal toko sebelumnya otomatis dibersihkan untuk menjaga privasi tenant |
| Masa aktif langganan toko habis | Respons API `402 Payment Required` otomatis mengarahkan ke halaman info perpanjangan |

---

## ⚡ Cara Menjalankan & Membangun Aplikasi

### Prasyarat
- Flutter SDK 3.x / Dart 3.x
- Android Studio / Xcode

### 1. Pengembangan Lokal (Development)
```bash
# Ambil dependensi
flutter pub get

# Jalankan pada emulator atau perangkat fisik (Self-Hosted)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000

# Atau jalankan mode Hosted (terhubung ke server cloud)
flutter run --dart-define=HOSTED=true
```

### 2. Build Produksi Android
```bash
# Build Android App Bundle (AAB) untuk Google Play Store
flutter build appbundle --release --dart-define=HOSTED=true

# Build Split APK (hemat ukuran unduhan per arsitektur CPU)
flutter build apk --release --split-per-abi --dart-define=HOSTED=true
```

---

## 🚀 CI/CD & Rilis Otomatis (GitHub Actions)

Aplikasi dilengkapi workflow otomatisasi rilis di [`.github/workflows/release-android.yml`](.github/workflows/release-android.yml):
- **Pemicu Rilis**: Berjalan otomatis saat pembuatan tag git versi `v*` (contoh: `v1.0.1`) atau via trigger manual (`workflow_dispatch`).
- **Signing Aman**: Keystore Android ditangani otomatis lewat GitHub Actions Secrets.
- **Output Rilis**:
  - `kasirtoko-${TAG}.aab` (Google Play Bundle resmi)
  - `kasirtoko-${TAG}-arm64-v8a.apk` (HP Android modern)
  - `kasirtoko-${TAG}-armeabi-v7a.apk` (HP Android lama)
  - `kasirtoko-${TAG}-x86_64.apk` (Emulator & perangkat Intel/AMD)
  - `checksums.txt` (Verifikasi integritas SHA-256)

---

## 🧪 Pengujian & Kualitas Kode

```bash
# Menjalankan 112 unit & widget test
flutter test --dart-define=HOSTED=true

# Menjalankan end-to-end (E2E) flow test terhadap server lokal
E2E_SERVER=http://127.0.0.1:8000 flutter test test/e2e
```

---

## 🎥 Materi Promosi Vertikal (`promo/`)

Direktori `promo/` memuat generator video promosi vertikal 60 detik (9:16 / 1080x1920) berbasis HTML, GSAP, dan Playwright dengan musik soundtrack sintetis:
- Video siap pakai: `promo/kasir-toko-promo.mp4`
- Jalankan pratinjau lokal: `cd promo && npm install && npm run preview`
- Render ulang video: `npm run render`

---

## 🌐 Sistem Backend Web POS

Aplikasi ini berkomunikasi dengan backend Laravel Multi-Tenant di repositori:
👉 **[Kasir Toko (Web POS)](../kasir-toko)**

---

## 📁 Struktur Direktori

```
lib/
├── core/             # Konfigurasi server, HTTP client (Dio), tema, cache offline, widget bersama
└── features/
    ├── auth/         # Autentikasi (password, social login Google/Apple), register toko, status paket
    ├── pos/          # Katalog, keranjang belanja, pembayaran QRIS/tunai/split, transaksi tertunda
    ├── shift/        # Buka/tutup shift kasir dan rekap uang laci
    ├── sales/        # Riwayat transaksi, detail penjualan, dan pembatalan (void)
    ├── offline/      # Snapshot katalog offline dan antrean sinkronisasi transaksi
    ├── printing/     # Integrasi printer thermal Bluetooth (ESC/POS)
    ├── products/     # Manajemen produk, kategori, dan kartu stok
    ├── customers/    # Manajemen pelanggan toko
    ├── receivables/  # Manajemen kasbon / piutang penjualan
    ├── reports/      # Laporan omzet, laba kotor, dan riwayat aktivitas
    ├── dashboard/    # Ringkasan penjualan dan status operasional
    ├── notifications/# Pusat notifikasi sistem dan pencarian global
    └── home/         # Navigasi bottom bar, drawer menu, dan akun toko
```

---

## ☕ Dukung & Donasi (Support / Donation)

Jika aplikasi ini bermanfaat bagi usaha atau proyek Anda, Anda dapat memberikan dukungan dan apresiasi pengembangan melalui **QRIS**:

<p align="center">
  <img src="docs/qris.png" width="280" alt="QRIS Donasi - RZ Printing" />
  <br>
  <em>Scan QRIS menggunakan BCA, Mandiri, BRI, BNI, GoPay, OVO, DANA, ShopeePay, atau aplikasi mobile banking lainnya.</em>
</p>

---

## 📬 Kontak & Pengembang

Dikembangkan oleh **rizalahmaddd**:
- **WhatsApp**: [+62 857-7777-5477](https://wa.me/6285777775477)
- **GitHub**: [@rizalahmaddd](https://github.com/rizalahmaddd)
- **Lokasi**: Kota Malang, Jawa Timur, Indonesia

Untuk diskusi teknis, pertanyaan integrasi POS, atau kerja sama kustomisasi, silakan hubungi kontak di atas.
