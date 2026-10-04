# Kasir Toko Mobile

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![State Management](https://img.shields.io/badge/State_Management-Riverpod-8A2BE2)](https://riverpod.dev)
[![HTTP Client](https://img.shields.io/badge/HTTP_Client-Dio-00599C)](https://pub.dev/packages/dio)
[![Thermal Printer](https://img.shields.io/badge/Thermal_Printer-ESC%2FPOS-1E88E5?logo=bluetooth&logoColor=white)](https://pub.dev/packages/esc_pos_utils_plus)
[![Tests](https://img.shields.io/badge/Tests-112_passed-success?logo=flutter&logoColor=white)](#-rilis--pengujian)

Aplikasi kasir mobile modern berbasis **Flutter** untuk smartphone dan tablet Android & iOS, terintegrasi penuh dengan backend SaaS [**Kasir Toko (Web POS)**](../kasir-toko). Mendukung mode cloud SaaS (hosted) maupun server sendiri (self-hosted).

---

## ✨ Fitur Utama

- 🛒 **Layar Kasir Adaptif**: Tampilan tablet dua kolom & ponsel, scan barcode kamera/Bluetooth, dan kuantitas desimal.
- 📶 **Mode Offline & Auto-Sync**: Tetap bertransaksi tanpa internet; antrean penjualan otomatis tersinkronisasi saat online.
- 💳 **Pembayaran & QRIS Auto-Bright**: Tunai, transfer, split, dan QRIS dinamis dengan fitur auto-maksimal kecerahan layar.
- 🖨️ **Struk Thermal Bluetooth**: Cetak langsung ke printer Bluetooth ESC/POS 58/80mm atau bagikan via WhatsApp.
- 📊 **Back Office Mobile**: Manajemen produk, mutasi stok, pelanggan, kasbon/piutang, dan laporan penjualan.
- 🔐 **Autentikasi Modern**: Social login Google & Apple, verifikasi OTP WhatsApp, dan kepatuhan store.

---

## ⚡ Menjalankan Aplikasi

```bash
flutter pub get

# Mode Cloud Hosted (https://kasirtoko.biz.id)
flutter run --dart-define=HOSTED=true

# Atau Mode Self-Hosted (Server Lokal)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

---

## 🚀 Rilis & Pengujian

- 📦 **Build Produksi (AAB & Split APK)**:
  ```bash
  flutter build appbundle --release --dart-define=HOSTED=true
  flutter build apk --release --split-per-abi --dart-define=HOSTED=true
  ```
- 🧪 **Pengujian**: `flutter test --dart-define=HOSTED=true` *(112 unit & widget tests passed)*
- 🎥 **Video Promosi Vertikal (promo/)**: Video promosi 60s siap tayang di `promo/kasir-toko-promo.mp4`
- 🌐 **Sistem Backend Web POS**: [Kasir Toko (Web POS)](../kasir-toko)

---

## ☕ Dukung & Donasi

Jika aplikasi ini bermanfaat bagi Anda, dukung pengembangan proyek ini melalui **QRIS**:

<p align="center">
  <img src="docs/qris.png" width="240" alt="QRIS Donasi - RZ Printing" />
  <br>
  <em>Scan QRIS menggunakan BCA, Mandiri, BRI, GoPay, OVO, DANA, ShopeePay, atau mobile banking lainnya.</em>
</p>

---

## 📬 Kontak

Dikembangkan oleh **rizalahmaddd**:
- **WhatsApp**: [+62 857-7777-5477](https://wa.me/6285777775477)
- **GitHub**: [@rizalahmaddd](https://github.com/rizalahmaddd)
- **Lokasi**: Kota Malang, Jawa Timur, Indonesia
