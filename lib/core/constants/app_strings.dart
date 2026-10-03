/// Kumpulan teks yang tampil ke pengguna, dikelompokkan per domain.
///
/// Teks statis berupa konstanta. Teks yang memiliki nilai dinamis
/// dijadikan fungsi dengan parameter.
library;

abstract final class AppStrings {
  static const appTitle = 'Kasir Toko';
}

abstract final class CoreStrings {
  // Pencarian & navigasi
  static const tooltipSearch = 'Cari';
  static const tooltipBack = 'Kembali';
  static const tooltipClearSearch = 'Hapus pencarian';

  // Dialog & aksi
  static const actionCancel = 'Batal';
  static const actionRetry = 'Coba Lagi';

  // Error & state
  static const errorLoadFailed = 'Gagal memuat data';
  static const errorGeneric = 'Terjadi kesalahan. Coba lagi.';
  static const errorNoServerResponse = 'Server tidak merespons. Periksa koneksi lalu coba lagi.';
  static const errorServerUnreachable = 'Tidak bisa terhubung ke server. Periksa koneksi dan alamat server.';
  static const errorOfflineNotCached =
      'Sedang offline dan data ini belum pernah dibuka di perangkat ini. Coba lagi setelah terhubung ke server.';
  static const errorSubscriptionExpired = 'Masa aktif toko sudah berakhir. Hubungi admin layanan.';
  static const errorForbidden = 'Akun Anda tidak punya izin untuk aksi ini.';
  static const errorNotFound = 'Data tidak ditemukan.';
  static const errorTooManyRequests = 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.';
  static String errorServerStatus(int? status) => 'Terjadi kesalahan di server ($status).';

  static const errorLinkOpenFailed = 'Tautan tidak bisa dibuka di perangkat ini.';

  // Filter & rentang tanggal
  static const filterAll = 'Semua';  static String filterTooltip(String label) => 'Filter $label';
  static String filterActiveLabel(String label, String value) => '$label: $value';
  static const dateToday = 'Hari ini';
  static const dateYesterday = 'Kemarin';
  static const dateLast7Short = '7 hari';
  static const dateLast7 = '7 hari terakhir';
  static const dateThisMonth = 'Bulan ini';
  static const dateLastMonth = 'Bulan lalu';
  static const datePickerTooltip = 'Pilih Tanggal';
  static const dateCustomRange = 'Pilih Rentang Tanggal...';
  static String dateRange(String start, String end) => '$start – $end';

  // Mata uang
  static const currencyPrefix = 'Rp ';

  // Metode pembayaran
  static const paymentCash = 'Tunai';
  static const paymentQris = 'QRIS';
  static const paymentTransfer = 'Transfer';
  static const paymentCard = 'Kartu';
  static const paymentCredit = 'Kasbon';

  // Pengatur jumlah
  static const quantityRemove = 'Hapus';
  static const quantityDecrease = 'Kurangi';
  static const quantityIncrease = 'Tambah';
  static String quantityWithUnit(String quantity, String unit) => '$quantity $unit';

  // Grafik
  static String chartTooltip(String label, String value) => '$label\n$value';

  // Satuan angka ringkas
  static const compactBillionSuffix = 'M';
  static const compactMillionSuffix = 'jt';
  static const compactThousandSuffix = 'rb';
  static const percentSuffix = '%';
}

abstract final class AuthStrings {
  // Login
  static const brandName = 'POS Kasir';
  static const brandBadge = 'MOBILE';
  static const brandTagline = 'Sistem Kasir & Point of Sale';
  static const loginTitleOtp = 'Masuk via WhatsApp';
  static const loginTitlePassword = 'Masuk ke Kasir';
  static const loginSubtitleOtp = 'Kode verifikasi sekali pakai akan dikirim ke WhatsApp Anda.';
  static const loginSubtitlePassword = 'Gunakan akun kasir atau manajer yang terdaftar pada sistem.';
  static const serverAddressLabel = 'Alamat Server';
  static const serverAddressHint = '192.168.1.10:8000 atau pos.toko.com';
  static const saveServerTooltip = 'Simpan Alamat';
  static const serverAddressRequired = 'Isi alamat server toko.';
  static const serverCardLabel = 'Server Toko';
  static const serverNotSet = 'Belum diatur';
  static const changeServer = 'Ganti';
  static const loginIdentifierLabel = 'Username, email, atau no. HP';
  static const loginIdentifierRequired = 'Isi username, email, atau nomor HP.';
  static const passwordRequired = 'Isi password.';
  static const otpLabel = 'Kode OTP WhatsApp';
  static const otpRequired = 'Isi kode verifikasi dari WhatsApp.';
  static const changeAccount = 'Ganti akun';
  static const resendCode = 'Kirim ulang kode';
  static const submitLogin = 'Masuk';
  static const submitVerify = 'Verifikasi & Masuk';
  static const submitSendOtp = 'Kirim Kode WhatsApp';
  static const switchToPassword = 'Masuk dengan Password';
  static const switchToOtp = 'Masuk via OTP WhatsApp';
  static const noShopRegister = 'Belum punya toko? Daftar gratis';

  static String otpSentInfo(String maskedPhone) => 'Kalau akun terdaftar, kode verifikasi dikirim ke $maskedPhone.';
  static String resendCodeCountdown(int seconds) => 'Kirim ulang ($seconds)';

  // Register
  static const registerTitle = 'Daftar Toko Baru';
  static const registerIntro =
      'Coba gratis selama masa uji coba. Akun ini jadi pemilik toko dan bisa menambah kasir sendiri.';
  static const shopNameLabel = 'Nama toko';
  static const shopNameHint = 'Contoh: Toko Sumber Rejeki';
  static const shopNameRequired = 'Isi nama toko.';
  static const ownerNameLabel = 'Nama pemilik';
  static const ownerNameRequired = 'Isi nama pemilik.';
  static const usernameLabel = 'Username';
  static const usernameRequired = 'Isi username.';
  static const emailLabel = 'Email';
  static const emailRequired = 'Isi email.';
  static const phoneLabel = 'Nomor HP (opsional)';
  static const phoneHint = '081234567890';
  static const passwordMinLength = 'Password minimal 8 karakter.';
  static const registerSubmit = 'Daftar & Mulai';
  static const alreadyHaveAccount = 'Sudah punya akun? Masuk';

  // Password
  static const passwordLabel = 'Password';
  static const showPasswordTooltip = 'Tampilkan password';
  static const hidePasswordTooltip = 'Sembunyikan password';

  // Tenant blocked / perpanjangan
  static const blockedTenantSuspended = 'Toko ini sedang dinonaktifkan. Hubungi admin layanan.';
  static const blockedTrialExpired = 'Masa uji coba toko ini sudah berakhir. Hubungi admin layanan untuk berlangganan.';
  static const blockedSubscriptionExpired = 'Langganan toko ini sudah berakhir. Hubungi admin layanan untuk memperpanjang.';
  static const blockedFallback = 'Toko ini tidak aktif.';
  static const defaultShopName = 'Toko';
  static const checkAgain = 'Periksa lagi';
  static const logout = 'Keluar';
  static const renewalHeading = 'Cara memperpanjang';
  static const serviceAdminLabel = 'Admin layanan';
  static const contactWhatsapp = 'Hubungi lewat WhatsApp';
  static const whatsappOpenFailed = 'WhatsApp tidak bisa dibuka.';

  static String blockedTitle(String shopName) => '$shopName belum bisa dipakai';
  static String blockedEndsAt(String formattedDate) => 'Masa aktif berakhir $formattedDate. Data toko tetap tersimpan.';
  static String renewalPlanPrice(String formattedPrice) => '$formattedPrice/bulan';
  static String whatsappRenewalMessage(String shopName) => 'Halo, saya ingin memperpanjang langganan toko $shopName.';

  // Social auth controller
  static const googleAuthTokenFailed = 'Gagal mendapatkan token autentikasi Google.';
  static const appleAuthTokenFailed = 'Gagal mendapatkan token autentikasi Apple.';
  static const socialActionRegister = 'Daftar';
  static const socialActionLogin = 'Masuk';
  static const socialDividerRegister = 'atau daftar dengan';
  static const socialDividerLogin = 'atau lanjutkan dengan';
  static const googleLogoLetter = 'G';

  static String socialGoogleError(String error) => 'Gagal masuk dengan Google: $error';
  static String socialAppleError(String error) => 'Gagal masuk dengan Apple: $error';
  static String continueWithApple(String action) => '$action dengan Apple';
  static String continueWithGoogle(String action) => '$action dengan Google';
}

abstract final class OnboardingStrings {
  // Metode pembayaran
  static const paymentLabelCash = 'Tunai';
  static const paymentLabelQris = 'QRIS';
  static const paymentLabelTransfer = 'Transfer';
  static const paymentLabelCard = 'Kartu';

  // Fitur
  static const featureLabelReceivables = 'Piutang (kasbon)';
  static const featureLabelCustomerDisplay = 'Layar pelanggan';

  // Pemilih preset
  static const titlePicker = 'Pilih Jenis Toko';
  static const logout = 'Keluar';
  static const pickerHeadingFirstRun = 'Pilih jenis usaha Anda untuk memulai';
  static const pickerHeadingChange = 'Ubah atau terapkan preset jenis toko baru';
  static const pickerSubtitleFirstRun =
      'Kategori, produk contoh, dan pengaturan kasir akan disesuaikan dengan jenis toko Anda. Anda tetap bisa memilih kategori dan mengubah pengaturannya.';
  static const pickerSubtitleChange =
      'Terapkan preset lain selama toko belum punya transaksi. Data yang sudah ada tidak akan dihapus.';
  static const skipButton = 'Lewati, mulai dari kosong';
  static const inUseBadge = 'Dipakai';

  // Hasil terapkan / lewati
  static const selectCategoryMin = 'Pilih minimal 1 kategori untuk toko Anda.';
  static const createdJoin = ' dan ';
  static const skipMessage = 'Toko siap dipakai. Tambahkan kategori dan produk kapan saja.';

  static String categoriesCreated(int count) => '$count kategori';
  static String sampleProductsCreated(int count) => '$count produk contoh';
  static String productsSkipped(int count) => '$count produk dilewati karena batas paket.';
  static String presetApplied(String label, String created, String skipped) => 'Preset $label diterapkan: $created dibuat.$skipped';

  // Bagian kategori
  static const categoriesHint = 'Uncheck kategori yang tidak diinginkan. Hanya kategori yang dicentang yang akan dibuat.';
  static const selectAll = 'Pilih Semua';
  static const clearAll = 'Batal Semua';
  static const includeSamplesTitle = 'Sertakan produk contoh';

  static String categoriesSection(int selected, int total) => 'Kategori Produk ($selected/$total)';
  static String includeSamplesSubtitlePartial(int count) => 'Hanya produk contoh untuk $count kategori yang dipilih.';
  static String includeSamplesSubtitle(int count) => '$count produk contoh dengan harga modal & jual awal.';

  // Bagian pengaturan kasir
  static const settingsSection = 'Pengaturan Kasir';
  static const settingsFlexibleBadge = 'Fleksibel';
  static const taxTitle = 'Pajak';
  static const taxDefaultLabel = 'PPN';
  static const taxNone = 'Tidak ada';
  static const taxSubtitle = 'Aktifkan pungutan pajak otomatis di struk kasir.';
  static const taxRateLabel = 'Tarif Pajak:';
  static const creditTitle = 'Bolehkan kasbon (piutang)';
  static const creditSubtitle = 'Izinkan metode bayar kasbon/tempo untuk pelanggan.';
  static const negativeStockTitle = 'Jual saat stok habis / minus';
  static const negativeStockSubtitle = 'Bolehkan transaksi saat stok sistem 0 atau minus.';
  static const paymentMethodLabel = 'Metode bayar';
  static const quickCashLabel = 'Uang cepat';
  static const receiptFooterLabel = 'Footer struk';

  static String taxSummary(String label, String quantity) => '$label $quantity%';

  // Modul dimatikan & terapkan
  static const disabledModulesTitle = 'Modul yang Dimatikan';
  static const applyNote = 'Catatan: Menerapkan preset akan memperbarui pengaturan kasir toko Anda.';
  static const applyButton = 'Terapkan';
}

abstract final class HomeStrings {
  // Navigasi bawah
  static const tabBeranda = 'Beranda';
  static const tabKasir = 'Kasir';
  static const tabTransaksi = 'Transaksi';
  static const tabProduk = 'Produk';
  static const tabMenu = 'Menu';
  static const tabBadgeOverflow = '99+';

  // Menu
  static const menuTitle = 'Menu';
  static const menuSearchHint = 'Cari menu (shift, stok, printer...)';
  static const menuSearchEmptyTitle = 'Menu tidak ditemukan';
  static String menuSearchEmptyDescription(String query) => 'Tidak ada menu yang cocok dengan "$query"';

  static const menuSectionSales = 'Penjualan';
  static const menuSectionProductsStock = 'Produk & Stok';
  static const menuSectionReportsActivity = 'Laporan & Aktivitas';
  static const menuSectionSettingsOthers = 'Pengaturan & Lainnya';

  static const menuShiftMineLabel = 'Shift saya';
  static const menuShiftMineCaption = 'Kas masuk/keluar, tutup shift';
  static const menuOfflineLabel = 'Mode offline';
  static const menuOfflineCaption = 'Katalog lokal & antrean';
  static String menuOfflineQueueCaption(int waiting) => '$waiting antrean menunggu sync';
  static const menuShiftHistoryLabel = 'Riwayat shift';
  static const menuShiftHistoryCaption = 'Rekap & selisih shift lalu';
  static const menuReceivablesLabel = 'Piutang (kasbon)';
  static const menuReceivablesCaption = 'Daftar & pelunasan kasbon';
  static const menuCategoriesLabel = 'Kategori';
  static const menuCategoriesCaption = 'Kelola kategori produk';
  static const menuStockLabel = 'Stok barang';
  static const menuStockCaption = 'Posisi stok, menipis, & habis';
  static const menuStockCardLabel = 'Kartu stok';
  static const menuStockCardCaption = 'Riwayat & audit mutasi stok';
  static const menuCustomersLabel = 'Pelanggan';
  static const menuCustomersCaption = 'Data kontak & tempo piutang';
  static const menuSalesReportLabel = 'Laporan penjualan';
  static const menuSalesReportCaption = 'Omzet, laba kotor, produk terlaris';
  static const menuActivityLogLabel = 'Log aktivitas';
  static const menuActivityLogCaption = 'Audit log kasir & admin';
  static const menuGlobalSearchLabel = 'Cari global';
  static const menuGlobalSearchCaption = 'Cari produk & riwayat cepat';
  static const menuNotificationsLabel = 'Notifikasi';
  static const menuNotificationsCaptionEmpty = 'Pemberitahuan sistem';
  static String menuNotificationsCaption(int unread) => '$unread pesan baru';
  static const menuStorePresetLabel = 'Preset jenis toko';
  static const menuStorePresetCaption = 'Hanya selama toko belum punya transaksi';
  static const menuReceiptPrinterLabel = 'Printer struk';
  static const menuReceiptPrinterCaption = 'Konfigurasi Bluetooth thermal';
  static const menuPosSettingsLabel = 'Pengaturan kasir';
  static const menuPosSettingsCaption = 'Stok minus, kasbon, & preferensi POS';
  static const menuAccountLabel = 'Akun & Profil';
  static const menuAccountCaption = 'Profil, password, tema, keluar';

  // Akun
  static const accountTitle = 'Akun';
  static const accountEditProfileTooltip = 'Ubah profil';
  static const accountChangePasswordTitle = 'Ganti password';
  static const accountChangePasswordSubtitle = 'Ubah kata sandi login akun';
  static const accountReceiptPrinterTitle = 'Printer struk';
  static const accountReceiptPrinterSubtitle = 'Bluetooth thermal & tes cetak';
  static const accountServerBackendTitle = 'Server Backend';
  static const accountThemeTitle = 'Tema Tampilan';
  static const accountThemeDarkActive = 'Mode gelap aktif';
  static const accountThemeLightActive = 'Mode terang aktif';
  static const accountLogoutButton = 'Keluar dari Aplikasi';
  static const accountLogoutAllButton = 'Keluar dari semua perangkat';
  static const accountDeleteButton = 'Hapus Akun Saya';
  static const accountAboutTitle = 'Tentang Aplikasi & Legal';
  static const accountAboutSubtitle = 'Kebijakan Privasi, EULA & Versi App';
  static const accountUsernameHandlePrefix = '@';
  static const accountNameInitialFallback = '?';
  static String accountUsernameHandle(String username) => '@$username';
  static String tenantPlanSubtitle(String planLabel, String? accessEndsAtLabel) =>
      'Paket $planLabel · ${accessEndsAtLabel == null ? 'tanpa batas waktu' : 'aktif s/d $accessEndsAtLabel'}';

  // Dialog keluar
  static const logoutDialogTitle = 'Keluar dari aplikasi?';
  static const logoutAllDialogTitle = 'Keluar dari semua perangkat?';
  static const logoutAllWarning = 'Semua HP, tablet, dan aplikasi lain yang login dengan akun ini harus login ulang.';
  static String logoutOfflineWarning(int waiting) =>
      '$waiting transaksi offline belum terkirim dan baru akan dikirim setelah Anda login lagi dengan akun ini.';
  static const logoutShiftOpenWarning = 'Shift Anda masih terbuka dan tidak ikut ditutup.';
  static const logoutReloginWarning = 'Anda perlu login lagi untuk memakai kasir di perangkat ini.';
  static const logoutConfirmLabel = 'Keluar';
  static const logoutLoading = 'Sedang keluar...';
  static const logoutAllLoading = 'Keluar dari semua perangkat...';

  // Dialog hapus akun & zona berbahaya
  static const dangerZoneTitle = 'Zona Berbahaya';
  static const dangerZoneDescription =
      'Penghapusan akun bersifat permanen. Seluruh data profil, token sesi, dan akses akun akan dihapus dan tidak dapat dipulihkan.';
  static const deleteAccountDialogTitle = 'Hapus Akun Permanen';
  static const deleteAccountDialogMessage =
      'Tindakan ini tidak dapat dibatalkan. Seluruh data akun Anda akan dihapus secara permanen dari server.';
  static const deleteAccountPrompt = 'Ketik kata HAPUS di bawah untuk mengonfirmasi:';
  static const deleteAccountKeyword = 'HAPUS';
  static const deleteAccountHint = 'Ketik "HAPUS" di sini';
  static const deleteAccountConfirmLabel = 'Hapus Akun Permanen';
  static String deleteAccountFailed(Object error) => 'Gagal menghapus akun: $error';

  // Profil
  static const profileSheetTitle = 'Ubah profil';
  static const profileNameLabel = 'Nama';
  static const profileUsernameLabel = 'Username';
  static const profileEmailLabel = 'Email';
  static const profilePhoneLabel = 'Nomor HP (untuk OTP WhatsApp)';
  static const profileSaveButton = 'Simpan';
  static const profileSavedMessage = 'Profil disimpan.';

  // Password
  static const passwordCurrentLabel = 'Password sekarang';
  static const passwordNewLabel = 'Password baru';
  static const passwordConfirmLabel = 'Ulangi password baru';
  static const passwordRevokeOthers = 'Keluarkan perangkat lain';
  static const passwordSubmitButton = 'Ganti Password';
  static const passwordMismatchError = 'Konfirmasi password baru tidak sama.';
  static const passwordChangedMessage = 'Password diganti.';
}

abstract final class DashboardStrings {
  // Sapaan
  static const greetingMorning = 'Selamat pagi';
  static const greetingAfternoon = 'Selamat siang';
  static const greetingEvening = 'Selamat sore';
  static const greetingNight = 'Selamat malam';
  static String greeting(int hour) =>
      hour < 11 ? greetingMorning : (hour < 15 ? greetingAfternoon : (hour < 18 ? greetingEvening : greetingNight));
  static String greetingLine(String greeting, String name) => '$greeting, $name';
  static const avatarInitialFallback = 'U';

  // App bar
  static const tooltipProfile = 'Buka Profil';
  static const tooltipSearch = 'Cari';
  static const tooltipNotifications = 'Notifikasi';
  static const themeLightTooltip = 'Mode terang';
  static const themeDarkTooltip = 'Mode gelap';

  // Kartu statistik
  static String statCaptionReceivables(String total) => 'Total $total';
  static const statCaptionLowStock = 'Perlu restock segera';
  static const statCaptionDefault = 'Lihat daftar detail';

  // Transaksi terakhir
  static const recentSalesTitle = 'Transaksi Terakhir';
  static const viewAllLabel = 'Lihat semua';
  static const statusVoided = 'Batal';
  static const statusReceivable = 'Kasbon';
  static String saleMetaLine(String time, int itemsCount, String? customerName) =>
      '$time · $itemsCount barang${customerName == null ? '' : ' · $customerName'}';

  // Banner shift & sync
  static const subscriptionExpiringToday = 'Masa aktif toko berakhir hari ini';
  static String subscriptionExpiringDays(int days) => 'Masa aktif toko tersisa $days hari lagi';
  static const subscriptionExpiringSubtitle = 'Perpanjang langganan melalui portal web toko Anda.';
  static String offlineSalesCount(int count) => '$count transaksi offline di perangkat';
  static const offlineNotSynced = 'Belum tersinkron ke server';
  static String syncSuccess(int count) => '$count transaksi berhasil dikirim ke server';
  static const syncInProgress = 'Sinkron...';
  static const syncAction = 'Kirim';
  static const shiftActiveTitle = 'Shift Kasir Aktif';
  static String shiftNumber(String number) => '#$number';
  static String shiftCashSummary(String openingCash, String? expectedCash) =>
      'Kas awal: $openingCash${expectedCash != null ? ' · Est. laci: $expectedCash' : ''}';
  static const manageCashLabel = 'Kelola Kas';
  static const shiftClosedTitle = 'Shift kasir belum dibuka';
  static const shiftClosedSubtitle = 'Buka shift untuk mencatat uang modal laci';
  static const openShiftButton = 'Buka Shift';

  // Aksi cepat
  static const quickActionStock = 'Stok Barang';
  static const quickActionSales = 'Penjualan';
  static const quickActionReceivables = 'Kasbon';
  static const quickActionAddProduct = 'Tambah Produk';
  static const quickActionReport = 'Laporan';
  static const quickActionPrinter = 'Printer';
  static const openPosTitle = 'Buka Kasir POS';
  static const openPosSubtitle = 'Mulai transaksi & cetak struk penjualan';

  // Penjualan hari ini
  static const todaySalesTitle = 'Penjualan Hari Ini';
  static String todayTransactionCount(int count) => '$count transaksi dicatat';
  static const todayNoTransactions = 'Belum ada transaksi';
  static const reportLinkLabel = 'Laporan';
  static const historyLinkLabel = 'Riwayat';
  static String percentChange(double diff) => '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%';
  static String vsYesterday(String amount) => 'vs kemarin ($amount)';
  static String yesterdayAmount(String amount) => 'Kemarin $amount';
  static const periodStart = 'Awal periode hari ini';
  static const metricTransactions = 'Transaksi';
  static const metricAvgTicket = 'Rata-rata/Struk';
  static const metricGrossProfit = 'Laba Kotor';
  static const metricCompleted = 'Selesai';
  static const metricEmptyValue = '-';
  static const metricCartValue = 'Nilai belanja';
  static String marginCaption(double margin) => '${margin.toStringAsFixed(0)}% margin';
  static const afterCogs = 'Setelah HPP';

  // Tren mingguan
  static const weeklyTrendTitle = 'Tren Omzet 7 Hari';
  static String weeklyTotal(String total) => 'Total 7 hari: $total';
  static const detailLabel = 'Detail';
  static String weeklyPeak(String peakLabel, String peakValue, String avg) =>
      'Tertinggi: $peakLabel ($peakValue) · Rata-rata $avg/hari';
  static String weeklyAverage(String avg) => 'Rata-rata omzet harian: $avg';

  // Stok menipis
  static const stockSafeTitle = 'Stok Produk Aman';
  static const stockSafeSubtitle = 'Tidak ada produk di bawah batas stok minimum';
  static const checkStockButton = 'Cek Stok';
  static const lowStockTitle = 'Stok Menipis & Habis';
  static String viewAllProducts(int count) => 'Lihat semua ($count)';
}

abstract final class NotificationStrings {
  static const notificationsTitle = 'Notifikasi';
  static const markAllRead = 'Tandai semua dibaca';
  static const emptyState = 'Belum ada notifikasi';

  static const searchHint = 'Cari produk, transaksi, pelanggan…';
  static const searchFailedTitle = 'Pencarian gagal';
  static const searchMinCharsTitle = 'Ketik minimal 2 huruf';
  static const searchNoResultsTitle = 'Tidak ada hasil';
  static const searchEmptyDescription = 'Cari produk berdasarkan nama, kode, nomor nota, atau nama pelanggan.';
  static const openInWebOnly = 'Data ini hanya bisa dibuka di aplikasi web.';
}

abstract final class PosStrings {
  static const cancel = 'Batal';
  static const save = 'Simpan';
  static const delete = 'Hapus';
  static const retry = 'Coba Lagi';

  static const defaultTaxLabel = 'Pajak';
  static const defaultUnit = 'pcs';
  static const cashierFallback = 'Kasir';

  static String codeNotFound(String code) => 'Kode $code tidak ditemukan.';

  // Pemindai kamera
  static const scanTitle = 'Scan Barcode / QR';
  static const torchTooltip = 'Lampu kilat';
  static const switchCameraTooltip = 'Ganti kamera';
  static const cameraError = 'Kamera tidak bisa dibuka. Izinkan akses kamera di pengaturan perangkat.';
  static const scanHint = 'Posisikan barcode di dalam kotak';

  // Panel katalog
  static const closeSearchTooltip = 'Tutup pencarian';
  static const openSearchTooltip = 'Cari produk';
  static const heldOrdersTooltip = 'Transaksi tertunda';
  static const scanBarcodeTooltip = 'Scan barcode';
  static const densitySliderTooltip = 'Ukuran tampilan produk';
  static const densityList = 'Daftar';
  static const densityCompact = 'Ringkas';
  static const densityStandard = 'Standar';
  static const densityLarge = 'Besar';
  static const densityGallery = 'Galeri';
  static String densityColumnsInfo(String name, int columns) => '$name · $columns kolom';
  static const lightModeTooltip = 'Mode terang';
  static const darkModeTooltip = 'Mode gelap';
  static const searchHint = 'Cari nama produk, SKU, barcode...';
  static const categoryAll = 'Semua';

  static const productNotFoundTitle = 'Produk tidak ditemukan';
  static const productNotFoundDescription = 'Coba kata kunci lain atau pilih kategori Semua.';
  static const quantityFieldLabel = 'Jumlah';
  static const addConfirm = 'Tambah';

  static String shiftCashierLabel(String number, String name) => '#$number · $name';

  // Stok produk
  static String stockOut(String name) => 'Stok $name habis.';
  static String stockRemaining(String name, String quantity, String unit) => 'Stok $name tersisa $quantity $unit.';
  static const stockStatusEmpty = 'kosong';
  static String stockStatusRemaining(String quantity, String unit) => 'sisa $quantity $unit';
  static String stockSystemNotice(String name, String status) => 'Stok sistem $name $status. Tetap ditambahkan.';
  static String productNoLongerSold(String name) => '$name sudah tidak dijual dan dikeluarkan dari keranjang.';
  static String priceChanged(String name, String price) => 'Harga $name berubah jadi $price.';
  static const errQuantityPositive = 'Jumlah harus lebih dari 0.';
  static String stockRemainingShort(String quantity) => 'Stok tersisa $quantity';
  static String stockRemainingWithUnit(String quantity, String unit) => 'Stok tersisa $quantity $unit.';

  static String stockBadge(String quantity) => 'Stok $quantity';
  static String stockLowBadge(String quantity) => 'Sisa $quantity';
  static String negativeStockLabel(String quantity, String unit) => 'Stok: $quantity $unit';
  static String onHandQuantity(String quantity, String unit) => '$quantity $unit';
  static const outOfStockBadge = 'HABIS';
  static const outOfStockLabel = 'Habis';
  static String inCartBadge(String quantity) => '$quantity×';
  static const productInitialsFallback = 'IT';

  // Transaksi tertunda
  static const holdTransactionTitle = 'Tunda transaksi';
  static const holdLabelField = 'Nama penanda (opsional)';
  static const holdLabelHint = 'mis. Bu Rina, meja 3';
  static const holdConfirm = 'Tunda';
  static const holdSuccessMessage = 'Transaksi ditunda. Buka lagi dari tombol jam di atas katalog.';

  // Keranjang
  static const clearCartTitle = 'Kosongkan keranjang?';
  static const clearCartContent = 'Semua barang di keranjang akan dihapus.';
  static const clearCartConfirm = 'Kosongkan';
  static const clearCartTooltip = 'Kosongkan keranjang';
  static const emptyCartTitle = 'Keranjang kosong';
  static const emptyCartDescription = 'Ketuk produk atau scan barcode untuk menambahkan barang.';

  static const defaultCustomerName = 'Pelanggan umum';
  static const memberLabel = 'Member / Pelanggan';
  static const chooseCustomerHint = 'Pilih member atau kasbon';
  static const cartAppBarTitle = 'Keranjang';
  static const openCartHint = 'Buka keranjang untuk checkout';
  static const payLabel = 'Bayar';

  static String cartItemCount(String quantity) => '$quantity barang';
  static String pricePerUnit(String price, String unit) => '$price / $unit';
  static String itemDiscount(String amount) => 'Diskon -$amount';

  static const itemDiscountLabel = 'Diskon barang ini';
  static const noteFieldLabel = 'Catatan (opsional)';
  static const noteFieldHint = 'mis. tanpa es';
  static const deleteItemButton = 'Hapus Barang';

  // Diskon
  static const discountSheetTitle = 'Diskon transaksi';
  static const discountRupiahSegment = 'Rupiah';
  static const discountPercentSegment = 'Persen';
  static const discountAmountField = 'Potongan';
  static const removeDiscountButton = 'Hapus Diskon';
  static const applyButton = 'Terapkan';
  static const errDiscountMaxPercent = 'Diskon persen maksimal 100%.';

  // Ringkasan keranjang
  static const subtotalLabel = 'Subtotal';
  static const discountLabel = 'Diskon';
  static const setDiscountLink = 'Atur Diskon >';
  static const totalLabel = 'Total';
  static const holdButton = 'Tunda';
  static String discountPercentLabel(String percent) => 'Diskon $percent%';
  static String discountAmountValue(String amount) => '-$amount';
  static String taxLabelRate(String label, String rate) => '$label $rate%';
  static String payAmountButton(String amount) => 'Bayar $amount';

  // Pemilih pelanggan
  static const chooseCustomerTitle = 'Pilih pelanggan';
  static const newCustomerButton = 'Baru';
  static const customerSearchHint = 'Nama, nomor HP, atau kode';
  static const customerNoNameSubtitle = 'Transaksi tanpa nama pelanggan';
  static const customerNotFoundTitle = 'Pelanggan tidak ditemukan';
  static const addNewCustomerButton = 'Tambah Pelanggan Baru';
  static const newCustomerDialogTitle = 'Pelanggan baru';
  static const customerNameField = 'Nama';
  static const customerPhoneField = 'Nomor HP / WhatsApp';
  static const saveCustomerButton = 'Simpan Pelanggan';
  static String releaseCustomer(String name) => 'Lepas $name';
  static String creditAmount(String amount) => 'Kasbon $amount';

  // Pembayaran
  static const paymentTitle = 'Pembayaran';
  static const removePaymentTooltip = 'Hapus pembayaran ini';
  static const hideNominalSettings = 'Sembunyikan Pengaturan Nominal';
  static const changeNominalSplitQris = 'Ubah Nominal / Split QRIS';
  static const qrisNotConfiguredWarning =
      'QRIS toko belum diatur di Pengaturan Kasir web. Minta pelanggan scan QRIS cetak lalu isi nominal.';
  static const cashReceivedLabel = 'Uang diterima';
  static const nominalLabel = 'Nominal';
  static const exactCashButton = 'Uang pas';
  static const changeLabel = 'Kembalian';
  static const shortageLabel = 'Kurang';
  static const referenceFieldLabel = 'No. referensi (opsional)';
  static const referenceFieldHint = 'mis. 4 digit akhir kartu';
  static const qrisPaidButton = 'Pembayaran QRIS Diterima';
  static const finishPaymentButton = 'Selesaikan Pembayaran';
  static const splitPaymentButton = 'Bayar sebagian, sisanya metode lain';
  static const creditConfirmTitle = 'Catat sebagai kasbon?';
  static const creditConfirmButton = 'Catat Kasbon';
  static const errFillAmountFirst = 'Isi nominal dulu.';
  static const errAmountSettlesBill = 'Nominal ini sudah melunasi tagihan. Tekan Selesaikan Pembayaran.';
  static const errNonCashExceedsTotal = 'Pembayaran non-tunai melebihi total. Non-tunai tidak punya kembalian.';
  static const errTaxSettingsChanged = 'Pengaturan pajak baru saja berubah. Periksa total lalu bayar lagi.';
  static const offlineStatusLabel = 'Menunggu sinkron';
  static const totalBillLabel = 'Total tagihan';
  static const remainingBillLabel = 'Sisa tagihan';

  static String paymentShortfall(String amount) => 'Pembayaran kurang $amount.';
  static String paymentShortfallCredit(String amount) => 'Pembayaran kurang $amount. Pilih pelanggan dulu kalau sisanya dicatat sebagai kasbon.';
  static String checkoutRetryMessage(String message) => '$message Tekan bayar lagi, transaksi tidak akan tercatat dua kali.';
  static String creditConfirmMessage(String amount, String customer) => 'Sisa $amount dicatat sebagai kasbon atas nama $customer.';
  static String ofTotal(String amount) => 'dari $amount';

  // QRIS
  static const qrisBrand = 'QRIS';
  static const qrisNationalStandard = 'Standar Pembayaran Nasional';
  static const qrisScanInstruction = 'Scan QR ini dengan GoPay, OVO, Dana, BCA, atau m-Banking';
  static const qrisTotalLabel = 'TOTAL PEMBAYARAN';
  static const qrisWaitingPayment = 'Menunggu pembayaran pembeli';

  // Ganti keranjang & pesanan tersimpan
  static const replaceCartTitle = 'Ganti keranjang sekarang?';
  static const replaceCartContent = 'Keranjang yang sedang dibuka akan dikosongkan. Tunda dulu kalau masih dibutuhkan.';
  static const replaceCartConfirm = 'Ganti Keranjang';
  static const deleteHeldOrderContent = 'Keranjang yang ditunda ini akan dihapus permanen.';
  static const heldOrdersTitle = 'Transaksi Tertunda';
  static const heldOrdersEmptyTitle = 'Tidak Ada Transaksi Tertunda';
  static const heldOrdersEmptyDescription = 'Tekan tombol "Tunda" di keranjang kasir untuk menyimpan transaksi sementara.';
  static const heldOrderResumeButton = 'Lanjut';
  static const heldOrderFallbackLabel = 'Pesanan';
  static const heldOrderFallbackLower = 'pesanan';
  static const heldPreviewItemFallback = 'Item';
  static const relativeJustNow = 'Baru saja';
  static const relativeYesterday = 'Kemarin';
  static String relativeMinutesAgo(int minutes) => '$minutes mnt lalu';
  static String relativeHoursAgo(int hours) => '$hours jam lalu';
  static String relativeDaysAgo(int days) => '$days hr lalu';
  static String heldOrderResumed(String label) => '$label dilanjutkan.';
  static String deleteHeldOrderTitle(String label) => 'Hapus $label?';
  static String heldOrdersSaved(int count) => '$count pesanan tersimpan';
  static String heldOrderNumber(int id) => 'Pesanan #$id';
  static String heldOrderIdBadge(int id) => '#$id';
  static String heldOrderItemCount(String quantity) => '$quantity item';
  static String heldPreviewItem(String quantity, String name) => '${quantity}x $name';
  static String heldPreviewMore(String names) => '$names, ...';

  // Sukses transaksi
  static const transactionSuccessTitle = 'Transaksi berhasil';
  static const viewReceiptButton = 'Lihat Struk';
  static const whatsappButton = 'WhatsApp';
  static const printReceiptButton = 'Cetak Struk';
  static const newTransactionButton = 'Transaksi Baru';
  static String creditNote(String amount, String customer) => 'Kasbon $amount atas nama $customer';

  static const posUnavailableTitle = 'Layar kasir tidak tersedia';
  static const posUnavailableDescription = 'Akun ini tidak punya izin berjualan, atau fitur kasir dimatikan di pengaturan toko.';

  // Pengaturan kasir
  static const settingsSavedMessage = 'Pengaturan kasir berhasil diperbarui.';
  static const settingsAppBarTitle = 'Pengaturan Kasir';
  static const sectionTransactionStock = 'Transaksi & Stok';
  static const allowNegativeStockTitle = 'Bolehkan jual saat stok habis';
  static const allowNegativeStockSubtitle =
      'Produk dengan stok sistem 0 atau minus tetap bisa dimasukkan ke keranjang kasir. Cocok jika barang fisik sudah ada tapi belum sempat di-input stok masuk.';
  static const allowCreditTitle = 'Bolehkan kasbon (piutang)';
  static const allowCreditSubtitle = 'Izinkan metode pembayaran kasbon / tempo untuk pelanggan terdaftar.';
  static const sectionReceiptPrint = 'Struk & Pencetakan';
  static const autoPrintTitle = 'Cetak struk otomatis';
  static const autoPrintSubtitle =
      'Otomatis kirim perintah cetak ke printer Bluetooth tersambung setelah transaksi selesai.';
  static const settingsGlobalNote =
      'Pengaturan ini berlaku secara toko / global dan langsung disinkronkan ke kasir web serta perangkat lain.';
  static const sectionDisplayScreen = 'Tampilan & Layar Perangkat';
  static const keepScreenOnTitle = 'Layar nyala terus di menu kasir';
  static const keepScreenOnSubtitle =
      'Mencegah layar HP/tablet mati atau terkunci otomatis saat berada di tab kasir.';
  static const qrFullBrightnessTitle = 'Kecerahan penuh saat tampil QR';
  static const qrFullBrightnessSubtitle =
      'Otomatis menaikkan kecerahan layar ke maksimal saat QRIS ditampilkan agar mudah dipindai pembeli.';
  static const settingsLocalNote =
      'Pengaturan tampilan layar ini disimpan secara lokal di perangkat ini.';
}

abstract final class ProductStrings {
  // Umum
  static const appTitleProducts = 'Produk';
  static const searchProductHint = 'Cari nama, SKU, atau barcode';
  static const emptyFilterHint = 'Ubah kata kunci atau filter.';
  static const actionReset = 'Reset';

  // Status & badge
  static const statusActive = 'Aktif';
  static const statusInactive = 'Nonaktif';
  static const statusOutOfStock = 'Habis';
  static const statusLowStock = 'Menipis';
  static const statusLowStockLong = 'Stok menipis';
  static const statusAvailable = 'Tersedia';
  static const statusNoStock = 'Tanpa stok';

  // Label umum
  static const labelCategory = 'Kategori';
  static const labelBarcode = 'Barcode';
  static const labelUnit = 'Satuan';
  static const labelCostPrice = 'Harga Modal (HPP)';
  static const labelCurrentStock = 'Stok Saat Ini';
  static const labelSave = 'Simpan';
  static const actionEdit = 'Ubah';
  static const actionDelete = 'Hapus';

  // Daftar produk
  static const tooltipSort = 'Urutkan';
  static const tooltipSearchByBarcode = 'Cari dengan barcode';
  static const filterLabelStatus = 'Status';
  static const filterAllStatus = 'Semua Status';
  static const filterLabelCategory = 'Kategori';
  static const filterAllCategories = 'Semua Kategori';
  static const emptyProductsTitle = 'Produk tidak ditemukan';

  static const sortOptions = [
    'Nama A-Z',
    'Nama Z-A',
    'Harga termurah',
    'Harga termahal',
    'Stok paling sedikit',
    'Stok paling banyak',
    'SKU',
  ];

  // Detail produk
  static const sectionStock = 'Stok';
  static const sectionStockCard = 'Kartu stok';
  static const actionViewAll = 'Lihat semua';
  static const emptyInlineMovements = 'Belum ada mutasi stok.';

  static const deleteProductConfirmTitle = 'Hapus produk?';
  static const deleteProductConfirmAction = 'Hapus';
  static String productDeleteConfirmMessage(String name) => '$name tidak akan muncul lagi di kasir. Riwayat transaksi tetap tersimpan.';
  static String productDeletedMessage(String name) => '$name dihapus.';

  static const photoSheetTitle = 'Foto Produk';
  static const actionTakePhoto = 'Ambil foto';
  static const actionPickFromGallery = 'Pilih dari galeri';
  static const actionDeletePhoto = 'Hapus foto';

  static const labelSellingPrice = 'Harga Jual';
  static const labelMinimumLimit = 'Batas minimum';
  static const labelStockValueCost = 'Nilai stok (modal)';
  static const actionStockInShort = 'Masuk';
  static const actionStockOutShort = 'Keluar';
  static const actionOpnameShort = 'Opname';

  static String priceMarginLabel(bool positive, String amount, String percent) => '${positive ? '+' : ''}$amount ($percent%)';
  static String stockQuantity(String quantity, String unit) => '$quantity $unit';

  // Form produk
  static const titleNewProduct = 'Tambah Produk Baru';
  static const titleEditProduct = 'Ubah Produk';
  static const titleLoadingProduct = 'Memuat Produk...';
  static const actionSaveNewProduct = 'Simpan Produk Baru';
  static const actionSaveChanges = 'Simpan Perubahan';
  static const newProductBannerBody =
      'Lengkapi informasi produk, harga jual, dan stok untuk memulai transaksi kasir.';

  static const validationSellingPriceRequired = 'Harga jual produk wajib diisi.';
  static String productAddedMessage(String name) => '$name berhasil ditambahkan.';
  static const messageProductUpdated = 'Perubahan berhasil disimpan.';

  static const sectionProductInfo = 'Informasi Produk';
  static const sectionProductInfoSubtitle = 'Nama barang, kategori, dan satuan dasar';
  static const fieldProductName = 'Nama Produk *';
  static const hintProductName = 'Misal: Kopi Susu Gula Aren, Kaos Polos';
  static const tooltipClearText = 'Hapus teks';
  static const validationProductNameRequired = 'Nama produk wajib diisi.';
  static const categoryNoCategory = 'Tanpa kategori (Umum)';
  static const fieldBaseUnit = 'Satuan Dasar *';
  static const hintBaseUnit = 'Misal: pcs, porsi, kg, btl';
  static const validationUnitRequired = 'Satuan wajib diisi.';

  static const unitOptions = [
    'pcs',
    'btl',
    'bks',
    'kg',
    'gr',
    'ltr',
    'dus',
    'pak',
    'sachet',
    'kaleng',
    'karung',
    'lusin',
  ];

  static const sectionBarcode = 'Identifikasi & Barcode';
  static const sectionBarcodeSubtitle = 'Kode unik barang dan scan barcode cepat';
  static const fieldSku = 'Kode SKU';
  static const hintSku = 'Otomatis';
  static const helperSku = 'Kosongkan = otomatis dibuat';
  static const hintBarcode = 'Scan / ketik kode';
  static const tooltipScanBarcodeCamera = 'Scan barcode kamera';

  static const sectionPriceMargin = 'Harga & Margin Keuntungan';
  static const sectionPriceMarginSubtitle = 'Atur harga jual dan pantau perkiraan laba kotor';
  static const fieldSellingPriceRequired = 'Harga Jual *';
  static const marginCostHint =
      'Masukkan harga modal (HPP) untuk melihat estimasi keuntungan dan margin persentase otomatis.';
  static const marginProfitTitle = 'Estimasi Keuntungan Bersih';
  static const marginLossTitle = 'Peringatan: Potensi Rugi';
  static const marginMarkupTitle = 'Markup Modal';
  static const unitFallback = 'satuan';
  static String marginPercentLabel(String percent) => 'Margin $percent%';
  static String markupPercentLabel(String percent) => '+$percent%';
  static String profitPerUnitLabel(String unit) => 'Laba per $unit';
  static String signedAmount(String sign, String amount) => '$sign$amount';

  static const sectionStockManage = 'Manajemen Stok & Inventaris';
  static const sectionStockManageSubtitle = 'Pantau ketersediaan fisik barang di kasir';
  static const switchTrackStock = 'Lacak Stok Barang';
  static const switchTrackStockSubtitle = 'Matikan untuk jasa atau produk yang tidak perlu dihitung stoknya.';
  static const fieldInitialStock = 'Stok Awal';
  static const hintZero = '0';
  static const helperInitialStock = 'Jumlah fisik awal';
  static const fieldMinimumLimit = 'Batas Minimum';
  static const helperMinStock = 'Peringatan stok menipis';
  static const fieldMinimumStockEdit = 'Batas Minimum Stok';
  static const helperMinStockEdit = 'Peringatan otomatis saat stok di bawah batas ini';
  static const infoStockAuditNotice =
      'Untuk menjaga keakuratan audit mutasi, stok fisik diubah melalui fitur Stok Masuk / Keluar atau Opname di halaman produk.';

  static const sectionStatusAvailability = 'Status & Ketersediaan';
  static const sectionStatusAvailabilitySubtitle = 'Pengaturan apakah produk ini aktif tampil di kasir';
  static const switchActiveForSale = 'Aktif Dijual di Kasir';
  static const switchActiveForSaleSubtitleOn = 'Produk muncul di katalog POS dan dapat langsung ditransaksikan kasir.';
  static const switchActiveForSaleSubtitleOff = 'Produk disembunyikan dari katalog kasir sementara waktu.';

  static String productSkuLabel(String sku) => 'SKU: $sku';
  static String productIdLabel(int id) => 'ID: #$id';

  // Mutasi stok
  static String movementByUser(String userName) => 'Oleh $userName';
  static String movementStockRange(String before, String after) => '$before → $after';
  static String movementDelta(bool positive, String quantity) => '${positive ? '+' : ''}$quantity';

  // Penyesuaian stok
  static const adjustTitleStockIn = 'Stok masuk';
  static const adjustTitleStockOut = 'Stok keluar';
  static const adjustTitleOpname = 'Stok opname';
  static const validationQuantityNumber = 'Isi jumlah dengan angka.';
  static const fieldPhysicalStock = 'Stok fisik hasil hitung';
  static const fieldQuantity = 'Jumlah';
  static const fieldReason = 'Alasan';
  static const fieldNoteOptional = 'Catatan (opsional)';
  static const hintAdjustStockIn = 'mis. kiriman supplier';
  static const hintAdjustStockOut = 'mis. rusak, kedaluwarsa, dipakai sendiri';
  static const hintAdjustOpname = 'mis. hitung ulang akhir bulan';
  static String stockAdjustRecordedMessage(String action, String productName) => '$action $productName dicatat.';
  static String stockAdjustSubtitle(String productName, String quantity, String unit) =>
      '$productName · stok sekarang $quantity $unit';
  static String stockAfterLabel(String quantity, String unit) => 'Stok setelahnya: $quantity $unit';
  static String unitCostField(String unit) => 'Harga beli per $unit (opsional)';

  // Layar stok
  static const appTitleStock = 'Stok barang';
  static const statTracked = 'Dilacak';
  static const statStockValue = 'Nilai stok';
  static const filterLabelStockStatus = 'Status Stok';
  static const filterAllStock = 'Semua Stok';
  static const filterStatusLowStock = 'Stok Menipis';
  static const filterStatusOutOfStock = 'Stok Habis';
  static const emptyStockTitle = 'Tidak ada barang';

  // Kartu stok
  static const searchMovementProductHint = 'Cari produk';
  static const filterLabelMovementType = 'Jenis';
  static const filterAllMovementTypes = 'Semua Jenis Mutasi';
  static const emptyMovementsTitle = 'Belum ada mutasi stok';
  static String movementScreenTitle(String productName) => 'Kartu stok · $productName';

  // Kategori
  static const searchCategoryHint = 'Cari kategori';
  static const emptyCategoriesTitle = 'Belum ada kategori';
  static const categoryDeleteConfirmTitle = 'Hapus kategori?';
  static const categoryDeleteConfirmAction = 'Hapus';
  static const categorySheetNew = 'Kategori baru';
  static const categorySheetEdit = 'Ubah kategori';
  static const fieldCategoryName = 'Nama kategori';
  static const fieldSortOrder = 'Urutan tampil';
  static const helperSortOrder = 'Angka kecil tampil lebih dulu di kasir.';
  static const actionDeleteCategory = 'Hapus kategori';
  static String categoryDeleteMessage(String name) => 'Kategori $name akan dihapus.';
  static String categoryStatsLabel(int count, int order) => '$count produk · Urutan $order';

  // Jenis mutasi stok
  static const movementTypeSale = 'Penjualan';
  static const movementTypeSaleVoid = 'Batal jual';
  static const movementTypeOpname = 'Opname';
  static const movementTypeInitial = 'Stok awal';
}

abstract final class SalesStrings {
  // Status & badge
  static const allStatuses = 'Semua Status';
  static const statusCompleted = 'Selesai';
  static const statusCredit = 'Kasbon';
  static const statusVoided = 'Dibatalkan';

  // Daftar penjualan
  static const salesHistoryTitle = 'Riwayat Transaksi';
  static const salesSearchHint = 'No. transaksi, pelanggan, atau barang';
  static const statusFilterLabel = 'Status';
  static const reset = 'Reset';
  static const emptySalesTitle = 'Belum ada transaksi';
  static const emptySalesDescription = 'Tidak ada transaksi di rentang tanggal dan filter ini.';
  static const totalSales = 'Total Penjualan';
  static String offlineQueuedNotice(int count, String total) => '$count transaksi offline ($total) belum terkirim, jadi belum masuk daftar ini.';
  static String transactionCount(int count) => '$count transaksi';
  static String voidedCount(int count) => '$count dibatalkan';

  // Tile penjualan
  static const generalCustomer = 'Pelanggan Umum';
  static String goodsCount(int count) => '$count barang';
  static String remainingAmount(String amount) => 'Sisa $amount';
  static String soldAtStamp(String date, String time) => '$date · $time';

  // Detail transaksi
  static const saleDetailTitle = 'Detail transaksi';
  static const printReceiptTooltip = 'Cetak struk';
  static String voidConfirmTitle(String number) => 'Batalkan $number?';
  static const voidReasonLabel = 'Alasan pembatalan';
  static const voidReasonHint = 'mis. salah input barang';
  static const voidTransaction = 'Batalkan Transaksi';
  static const voidReasonEmpty = 'Tulis alasan pembatalan.';
  static const voidSuccess = 'Transaksi dibatalkan. Stok dikembalikan.';
  static String cashierLabel(String name) => 'Kasir: $name';
  static String shiftLabel(String number) => 'Shift #$number';
  static String voidedBanner(String voidedAt, String reason) => 'Dibatalkan $voidedAt: $reason';
  static const itemListTitle = 'Daftar Barang';
  static String itemCount(int count) => '$count item';
  static String itemQuantityPrice(String quantity, String unit, String price) => '$quantity $unit × $price';
  static String itemDiscount(String amount) => 'Diskon -$amount';
  static String noteWithValue(String note) => 'Catatan: $note';
  static const paymentDetailsTitle = 'Rincian Pembayaran';
  static const subtotal = 'Subtotal';
  static const discount = 'Diskon';
  static String taxLabel(String rate) => 'Pajak $rate%';
  static const totalTransaction = 'Total Transaksi';
  static const cashReceived = 'Uang Diterima';
  static const change = 'Kembalian';
  static const remainingCredit = 'Sisa Kasbon';
  static String collectPaymentButton(String amount) => 'Catat Pelunasan $amount';
  static const viewReceipt = 'Lihat Struk';
  static const whatsapp = 'WhatsApp';

  // Struk
  static const receiptTitle = 'Struk Pembelian';
  static const copyTextTooltip = 'Salin Teks';
  static const receiptCopied = 'Teks struk berhasil disalin';
  static const proofOfPayment = 'BUKTI PEMBAYARAN';
  static const printReceipt = 'Cetak Struk';
  static const receiptPrinted = 'Struk dicetak.';
  static const share = 'Bagikan';
  static String receiptShareSubject(String number) => 'Struk $number';
  static const totalFallback = 'TOTAL';
  static const itemDiscountLabel = 'Diskon item';
  static const whatsappUnavailable = 'WhatsApp tidak bisa dibuka di perangkat ini.';
}

abstract final class ReceivableStrings {
  // Metode pembayaran
  static const methodCash = 'Tunai';
  static const methodQris = 'QRIS';
  static const methodTransfer = 'Transfer';
  static const methodCard = 'Kartu';

  // Daftar piutang
  static const receivablesTitle = 'Piutang (kasbon)';
  static const receivablesSearchHint = 'No. transaksi, nama, atau HP pelanggan';
  static const totalOutstanding = 'Total belum lunas';
  static const customerLabel = 'Pelanggan';
  static const noReceivablesTitle = 'Tidak ada kasbon';
  static const noReceivablesDescription = 'Semua kasbon sudah lunas.';
  static const unnamedCustomer = 'Tanpa Nama';
  static const today = 'Hari ini';
  static String daysAgo(int days) => '$days hari';
  static const remainingCredit = 'Sisa Kasbon';
  static String totalAmount(String amount) => 'Total $amount';
  static String paidAmount(String amount) => 'Dibayar $amount';
  static const paymentHistoryTooltip = 'Riwayat pembayaran';
  static const payButton = 'Bayar';
  static const metaSeparator = ' · ';

  // Pelunasan
  static const recordPaymentTitle = 'Catat pelunasan';
  static String paymentSheetSubtitle(String number, String? customerName, String due) =>
      '$number${customerName == null ? '' : ' · $customerName'} · sisa $due';
  static String creditPaidOff(String number) => 'Kasbon $number lunas.';
  static String paymentRecorded(String amount) => 'Pelunasan dicatat. Sisa $amount.';
  static const viewPriorPayments = 'Lihat Riwayat Pembayaran Sebelumnya';
  static const amountPaidLabel = 'Nominal dibayar';
  static const paidOff = 'Lunas';
  static const half = 'Setengah';
  static const hideDynamicQris = 'Sembunyikan QRIS Dinamis';
  static const qrisAmountPlaceholder = 'Sesuai Nominal';
  static String showDynamicQris(String amount) => 'Tampilkan QRIS Dinamis ($amount)';
  static const amountRequired = 'Isi nominal pembayaran terlebih dahulu.';
  static const referenceLabel = 'No. referensi (opsional)';
  static const cashPaymentNote = 'Pelunasan tunai masuk ke rekap laci shift yang sedang buka.';
  static const savePayment = 'Simpan Pelunasan';

  // Riwayat pembayaran
  static const paymentHistoryTitle = 'Riwayat Pembayaran';
  static String paymentHistorySubtitle(String number, String? customerName) => '$number${customerName == null ? '' : ' · $customerName'}';
  static const totalBill = 'Total Tagihan';
  static const alreadyPaid = 'Sudah Dibayar';
  static String allIncomingTransactions(int count) => 'Semua Transaksi Masuk ($count)';
  static const noPaymentsTitle = 'Belum ada pembayaran';
  static const noPaymentsDescription = 'Belum ada catatan pembayaran yang tercatat pada kasbon ini.';
  static const initialPayment = 'Pembayaran Awal';
  static const settlement = 'Pelunasan';
  static String referencePrefix(String reference) => 'Ref: $reference';
  static String receivedBy(String name) => 'Penerima: $name';
}

abstract final class ReportStrings {
  // Tab
  static const reportTitle = 'Laporan penjualan';
  static const tabOverview = 'Ikhtisar';
  static const tabDaily = 'Harian';
  static const tabProducts = 'Produk';

  // Pertumbuhan
  static const noComparison = 'belum ada pembanding';
  static const trendUp = '▲';
  static const trendDown = '▼';
  static String growthVsLastPeriod(String indicator, String percent) => '$indicator $percent vs periode lalu';

  // Ikhtisar
  static const omzet = 'Omzet';
  static const grossProfit = 'Laba kotor';
  static String marginLabel(String percent) => 'Margin $percent';
  static const transactions = 'Transaksi';
  static const average = 'Rata-rata';
  static String itemsPerTransaction(String quantity) => '$quantity barang/transaksi';
  static const credit = 'Kasbon';
  static String transactionCount(int count) => '$count transaksi';
  static const discount = 'Diskon';
  static String discountOfRevenue(String percent) => '$percent dari omzet';
  static const voided = 'Dibatalkan';
  static const itemsSold = 'Barang terjual';

  static const revenueTrend = 'Tren omzet';
  static const paymentMethods = 'Metode pembayaran';
  static const noPayments = 'Belum ada pembayaran.';
  static String paymentShareCaption(int count, String percent) => '$count transaksi · $percent';
  static const topProducts = 'Produk terlaris';
  static const noSales = 'Belum ada penjualan.';
  static String productCaption(String quantity, String unit, String profit, String margin) =>
      '$quantity $unit · laba $profit ($margin)';
  static const byCategory = 'Per kategori';
  static String profitLabel(String amount) => 'Laba $amount';
  static const busyHours = 'Jam ramai';
  static const byCashier = 'Per kasir';
  static const topCustomers = 'Pelanggan teratas';
  static String customerSegments(String member, String general) => 'Pelanggan terdaftar: $member omzet · umum $general';

  static const copySummary = 'Salin ringkasan';
  static const summaryCopied = 'Ringkasan laporan berhasil disalin ke papan klip';
  static const summaryNotReady = 'Data laporan belum siap disalin';
  static const financialHealth = 'Kesehatan finansial';
  static const riskMetrics = 'Risiko & operasional';
  static const highestDay = 'Tertinggi';
  static const highMargin = 'Margin tinggi';
  static const unpaidNote = 'nota belum lunas';
  static const cancelledNote = 'nota dibatalkan';
  static String peakHourAlert(String hour, String amount) => 'Jam tersibuk di jam $hour ($amount)';

  // Tab harian
  static const costOfGoods = 'Modal (HPP)';
  static String revenueWithMargin(String revenue, String margin) => '$revenue · $margin';
  static const byDay = 'Per hari';
  static const noSalesInPeriod = 'Tidak ada penjualan di periode ini';
  static const today = 'Hari ini';
  static String dailyCaption(int count, String quantity) => '$count transaksi · $quantity barang';
  static String profitAmount(String amount) => 'laba $amount';

  // Tab produk
  static const sortLabel = 'Urutan';
  static const sortProfit = 'Laba';
  static const sortQuantity = 'Jumlah';
  static const sortMargin = 'Margin';
  static String sortBy(String label) => 'Urut $label';
  static const closeSearch = 'Tutup pencarian';
  static const searchProducts = 'Cari produk';
  static const noProductsSold = 'Tidak ada produk terjual';
  static String productCategoryQuantity(String category, String quantity, String unit) => '$category · $quantity $unit';
  static String profitWithMargin(String amount, String margin) => 'laba $amount ($margin)';

  // Log aktivitas
  static const logAudit = 'Perubahan data';
  static const logAuth = 'Login';
  static const logSettings = 'Pengaturan';
  static const logRoles = 'Peran';
  static const logExport = 'Ekspor';
  static const activityLogTitle = 'Log aktivitas';
  static const activitySearchHint = 'Cari aktivitas';
  static const logCategoryLabel = 'Kategori Log';
  static const allActivities = 'Semua Aktivitas';
  static const noActivityTitle = 'Belum ada aktivitas';
  static const activityTitle = 'Aktivitas';
  static const timeLabel = 'Waktu';
  static const byLabel = 'Oleh';
  static const systemActor = 'Sistem';
  static const dataLabel = 'Data';
  static const ipAddressLabel = 'Alamat IP';
  static const reasonLabel = 'Alasan';
  static const changesLabel = 'Perubahan';
  static String changeFromTo(String before, String after) => '$before → $after';
}

abstract final class CustomerStrings {
  // Form
  static const newCustomerTitle = 'Pelanggan baru';
  static const editCustomerTitle = 'Ubah pelanggan';
  static const nameLabel = 'Nama';
  static const codeLabel = 'Kode pelanggan';
  static const codeHint = 'mis. PLG-0012';
  static const phoneLabel = 'Nomor HP / WhatsApp';
  static const typeLabel = 'Tipe (opsional)';
  static const typeHint = 'mis. Member, Grosir, Warung';
  static const contactLabel = 'Nama kontak (opsional)';
  static const emailLabel = 'Email (opsional)';
  static const addressLabel = 'Alamat (opsional)';
  static const npwpLabel = 'NPWP (opsional)';
  static const paymentTermLabel = 'Tempo bayar (hari)';
  static const paymentTermHint = '0 = tunai';
  static const active = 'Aktif';
  static const saveButton = 'Simpan';
  static const changesSaved = 'Perubahan disimpan.';

  // Daftar
  static const screenTitle = 'Pelanggan';
  static const searchHint = 'Cari nama, kode, atau nomor HP';
  static const statusFilterLabel = 'Status';
  static const allCustomers = 'Semua Pelanggan';
  static const activeCustomers = 'Pelanggan Aktif';
  static const inactiveCustomers = 'Pelanggan Nonaktif';
  static const noCustomersFound = 'Pelanggan tidak ditemukan';
  static const inactive = 'Nonaktif';

  // Detail
  static const editTooltip = 'Ubah';
  static const deleteTooltip = 'Hapus';
  static const teleponButton = 'Telepon';
  static const whatsappButton = 'WhatsApp';
  static const whatsappOpenFailed = 'WhatsApp tidak bisa dibuka.';
  static const phoneInfoLabel = 'Nomor HP';
  static const contactPersonInfoLabel = 'Kontak person';
  static const emailInfoLabel = 'Email';
  static const addressInfoLabel = 'Alamat';
  static const npwpInfoLabel = 'NPWP';
  static const paymentTermInfoLabel = 'Tempo bayar';
  static const cashPayment = 'Tunai';
  static const deleteDialogTitle = 'Hapus pelanggan?';
  static const deleteConfirmButton = 'Hapus';
  static const yearlySpendLabel = 'Belanja setahun';
  static const unpaidReceivablesLabel = 'Kasbon belum lunas';
  static const recentTransactionsTitle = 'Transaksi terakhir';
  static const noTransactionsLastYear = 'Belum ada transaksi dalam setahun terakhir.';

  static String customerAdded(String name) => '$name ditambahkan.';
  static String fieldRequired(String label) => '$label wajib diisi.';
  static String paymentTermDays(int days) => '$days hari';
  static String deleteCustomerMessage(String name) => '$name akan dihapus. Riwayat transaksinya tetap tersimpan.';
  static String customerDeleted(String name) => '$name dihapus.';
  static String transactionCount(int count) => '$count transaksi';
}

abstract final class ShiftStrings {
  // Riwayat shift
  static const historyTitle = 'Riwayat Shift';
  static const statusFilterLabel = 'Status Shift';
  static const allShifts = 'Semua Shift';
  static const openShifts = 'Sedang Buka';
  static const closedShifts = 'Ditutup';
  static const varianceShifts = 'Ada Selisih';
  static const noShiftsTitle = 'Belum Ada Shift';
  static const noShiftsDescription = 'Riwayat buka dan tutup kasir akan tercatat di sini.';
  static const openBadge = 'Buka';
  static const overBadge = 'Lebih';
  static const shortBadge = 'Kurang';
  static const doneBadge = 'Selesai';
  static const cashDifferenceLabel = 'Selisih kas: ';
  static const methodQris = 'QRIS';
  static const methodTransfer = 'Transfer';
  static const methodCard = 'Kartu';

  // Kas masuk & keluar
  static const cashInRecorded = 'Kas masuk dicatat.';
  static const cashOutRecorded = 'Kas keluar dicatat.';
  static const recordCashInTitle = 'Catat kas masuk';
  static const recordCashOutTitle = 'Catat kas keluar';
  static const amountLabel = 'Nominal';
  static const reasonLabel = 'Keperluan';
  static const cashInReasonHint = 'mis. tambah uang kembalian';
  static const cashOutReasonHint = 'mis. beli es batu, setor ke pemilik';
  static const saveCashInButton = 'Simpan Kas Masuk';
  static const saveCashOutButton = 'Simpan Kas Keluar';

  // Kartu kas laci
  static const shiftActiveBadge = 'Shift Aktif';
  static const shiftClosedBadge = 'Shift Ditutup';
  static const expectedInDrawerLabel = 'Uang di laci seharusnya';
  static const physicalCashAtCloseLabel = 'Uang fisik saat ditutup';
  static const openingCashMiniLabel = 'Modal Awal';
  static const cashInMiniLabel = 'Kas Masuk';
  static const cashOutMiniLabel = 'Kas Keluar';

  // Tutup shift
  static const fillPhysicalCashError = 'Hitung dan isi uang fisik di laci.';
  static const physicalCashCountedLabel = 'Uang fisik yang dihitung';
  static const noDifferenceLabel = 'Pas, tidak ada selisih.';
  static const noteOptionalLabel = 'Catatan (opsional)';
  static const closeShiftButton = 'Tutup Shift';

  // Layar shift
  static const myShiftTitle = 'Shift saya';
  static const shiftHistoryTooltip = 'Riwayat shift';
  static const printRecapTooltip = 'Cetak rekap';
  static const recapPrinted = 'Rekap shift dicetak.';
  static const reloadTooltip = 'Muat ulang';
  static const shiftFallbackTitle = 'Shift';
  static const setOpeningCashSubtitle = 'Setor modal / penerimaan';
  static const withdrawCashSubtitle = 'Tarik kas / pengeluaran';
  static const cashFlowRecapTitle = 'Rekapitulasi Arus Kas';
  static const openingCashLabel = 'Modal awal';
  static const cashSalesLabel = 'Penjualan tunai';
  static const cashReceivableSettlementLabel = 'Pelunasan kasbon tunai';
  static const cashInLabel = 'Kas masuk';
  static const cashOutLabel = 'Kas keluar';
  static const countedCashLabel = 'Uang fisik dihitung';
  static const differenceLabel = 'Selisih';
  static const salesPerformanceTitle = 'Performa Penjualan';
  static const completedTransactionsLabel = 'Transaksi selesai';
  static const totalSalesLabel = 'Total penjualan';
  static const voidedLabel = 'Dibatalkan';
  static const cashMovementsTitle = 'Kas masuk & keluar';
  static const noCashMovements = 'Belum ada kas masuk atau keluar di shift ini.';
  static const closeShiftCardTitle = 'Tutup Shift Kasir';
  static const closeShiftCardDescription = 'Pastikan semua pesanan telah selesai dan hitung uang tunai di laci kasir.';
  static const noTransactions = 'Belum ada transaksi.';

  // Buka shift
  static const openShiftTitle = 'Buka shift dulu';
  static const openShiftDescription =
      'Hitung uang di laci sebelum mulai berjualan. Angka ini jadi patokan saat tutup shift nanti.';
  static const openingCashFieldLabel = 'Modal awal di laci';
  static const openShiftButton = 'Buka Shift';

  static String shiftTimeRange(String openedAt, String? closedAt) => closedAt == null ? '$openedAt – Sekarang' : '$openedAt – $closedAt';
  static String transactionCount(int count) => '$count transaksi';
  static String cashierLabel(String name) => 'Kasir: $name';
  static String openedAtLabel(String value) => 'Dibuka $value';
  static String closedAtLabel(String value, String? by) => by == null ? 'Ditutup $value' : 'Ditutup $value oleh $by';
  static String shiftClosedExact(String number) => 'Shift $number ditutup. Uang laci pas.';
  static String shiftClosedWithDifference(String number, String difference) => 'Shift $number ditutup dengan selisih $difference.';
  static String closeShiftTitle(String number) => 'Tutup shift $number';
  static String expectedCashInDrawer(String amount) => 'Seharusnya ada $amount di laci.';
  static String differenceAmountLabel(String value) => 'Selisih $value';
  static String closingNoteLabel(String note) => 'Catatan tutup: $note';
  static String movementSubtitle(String typeLabel, String time) => '$typeLabel · $time';
  static String pendingOfflineMessage(int count) => 'Masih ada $count transaksi offline yang belum terkirim. Kirim dulu di Menu → Mode offline.';
  static String transactionsHeader(int count) => 'Transaksi ($count)';
}

abstract final class PrintingStrings {
  // Aksi cetak
  static const receiptPrinted = 'Struk dicetak.';
  static const testPageSent = 'Halaman tes dikirim ke printer.';
  static const printTestPageButton = 'Cetak halaman tes';
  static const selectPrinterFirst = 'Pilih printer dulu untuk tes cetak';

  // Pengaturan
  static const printerScreenTitle = 'Printer struk';
  static const bluetoothDevicesTitle = 'Perangkat Bluetooth';
  static const closeButton = 'Tutup';
  static const scanButton = 'Pindai';
  static const paperAndPrintTitle = 'Kertas & cetak';
  static const receiptContentTitle = 'Isi struk';
  static const previewTitle = 'Pratinjau';
  static const saleReceiptPreview = 'Struk penjualan';
  static const testPagePreview = 'Halaman tes';
  static const salePreviewNote = 'Contoh transaksi. Isi struk asli mengikuti data penjualan.';
  static const testPreviewNote = 'Baris angka harus pas satu baris penuh. Kalau terpotong, ganti lebar kertas.';
  static const printerListHidden = 'Daftar disembunyikan karena printer sudah aktif.';
  static const changePrinterButton = 'Ganti printer';
  static const pairPrinterHint = 'Nyalakan printer dan pair dulu di pengaturan Bluetooth HP/tablet, lalu pilih dari daftar ini.';
  static const noPairedPrinterTitle = 'Belum ada printer yang di-pair';
  static const noPairedPrinterDescription = 'Pair printer di pengaturan Bluetooth, lalu tekan Pindai.';
  static const noPrinterLabel = 'Belum ada printer';
  static const activeStatus = 'Aktif';
  static const inactiveStatus = 'Nonaktif';
  static const selectPrinterHint = 'Pilih printer Bluetooth thermal di bawah.';
  static const forgetPrinterTooltip = 'Lupakan printer';
  static const forgetPrinterDialogTitle = 'Lupakan printer?';
  static const forgetPrinterDialogMessage = 'Struk tidak bisa dicetak sampai printer dipilih lagi.';
  static const forgetPrinterConfirm = 'Lupakan';
  static const checkingPrinter = 'Mengecek printer...';
  static const testPrinterConnection = 'Tes koneksi printer';
  static const paperWidthLabel = 'Lebar kertas';
  static const paperWidth58 = '58 mm';
  static const paperWidth80 = '80 mm';
  static const printCountLabel = 'Jumlah cetak';
  static const printCountHint = 'Berapa lembar struk penjualan yang keluar tiap kali cetak.';
  static const copiesOne = '1';
  static const copiesTwo = '2';
  static const copiesThree = '3';
  static const feedLinesLabel = 'Jarak akhir struk';
  static const feedLinesHint = 'Baris kosong sebelum kertas dipotong atau disobek.';
  static const feedTight = 'Rapat';
  static const feedNormal = 'Normal';
  static const feedLoose = 'Longgar';
  static const autoCutLabel = 'Potong kertas otomatis';
  static const autoCutHint = 'Matikan kalau printer tidak punya pemotong.';
  static const autoPrintLabel = 'Cetak otomatis setelah bayar';
  static const autoPrintEnabledHint = 'Struk langsung keluar saat transaksi selesai.';
  static const autoPrintDisabledHint = 'Pilih printer dulu untuk mengaktifkan.';
  static const showStoreInfoLabel = 'Tampilkan alamat & telepon toko';
  static const showStoreInfoHint = 'Matikan supaya struk lebih pendek dan hemat kertas.';
  static const fromStoreSettings = 'DARI PENGATURAN TOKO';
  static const reloadTooltip = 'Muat ulang';
  static const storeNameLabel = 'Nama toko';
  static const addressLabel = 'Alamat';
  static const phoneLabel = 'Telepon';
  static const receiptHeaderLabel = 'Kepala struk';
  static const receiptFooterLabel = 'Kaki struk';
  static const editOnWebHint =
      'Ubah lewat web: Pengaturan → Profil Perusahaan (nama, alamat, telepon) dan Pengaturan Kasir (kepala & kaki struk).';
  static const unnamedDevice = 'Tanpa nama';
  static const selectedDevice = 'Terpilih';
  static const selectDevice = 'Pilih';

  // Pesan printer
  static const bluetoothUnsupported = 'Printer Bluetooth tidak didukung di perangkat ini.';
  static const bluetoothPhoneOff = 'Bluetooth HP Anda sedang mati. Nyalakan Bluetooth dulu.';
  static const permissionNotGranted = 'Izin Bluetooth belum diberikan. Izinkan di pengaturan HP lalu coba lagi.';
  static const permissionNotGrantedShort = 'Izin Bluetooth belum diberikan.';
  static const bluetoothOff = 'Bluetooth mati. Nyalakan Bluetooth lalu coba lagi.';
  static const printerNotSelected = 'Printer belum dipilih. Atur di Menu → Printer struk.';
  static const sendToPrinterFailed = 'Gagal mengirim data ke printer. Coba lagi.';

  // Struk penjualan
  static const defaultStoreName = 'Toko';
  static const defaultTaxLabel = 'Pajak';
  static const receiptNoLabel = 'No';
  static const receiptDateLabel = 'Tanggal';
  static const receiptCashierLabel = 'Kasir';
  static const receiptCustomerLabel = 'Pelanggan';
  static const receiptVoided = '*** DIBATALKAN ***';
  static const receiptItemDiscountLabel = '  Diskon';
  static const receiptDiscountLabel = 'Diskon';
  static const receiptTotalLabel = 'TOTAL';
  static const receiptChangeLabel = 'Kembali';
  static const receiptDueLabel = 'Sisa kasbon';
  static const methodQris = 'QRIS';
  static const methodTransfer = 'Transfer';
  static const methodCard = 'Kartu';

  // Rekap shift
  static const shiftRecapTitle = 'REKAP SHIFT';
  static const receiptOpenedLabel = 'Buka';
  static const receiptClosedLabel = 'Tutup';
  static const summaryOpening = 'Modal awal';
  static const summaryCashSales = 'Penjualan tunai';
  static const summaryCashReceivableSettlement = 'Pelunasan tunai';
  static const summaryCashIn = 'Kas masuk';
  static const summaryCashOut = 'Kas keluar';
  static const summaryExpected = 'Seharusnya';
  static const summaryCounted = 'Dihitung';
  static const summaryDifference = 'Selisih';
  static const summaryTransactions = 'Transaksi';
  static const summaryTotalSales = 'Total penjualan';
  static const summaryVoided = 'Dibatalkan';

  // Halaman tes
  static const testSuccess = 'TES PRINTER BERHASIL';
  static const testPaperLabel = 'Kertas';
  static const testCharsPerLineLabel = 'Karakter per baris';
  static const testPrintedLabel = 'Dicetak';
  static const testBoldText = 'Teks tebal';
  static const testCenteredText = 'Rata tengah';
  static const testLargeText = 'BESAR';

  static String printerProblem(String detail) => 'Printer bermasalah: $detail';
  static String printerConnected(String name) => 'Printer $name terhubung dan siap digunakan.';
  static String cannotConnectPrinter(String name) => 'Tidak dapat terhubung ke $name. Pastikan printer menyala dan dekat.';
  static String connectionCheckFailed(String error) => 'Gagal cek koneksi: $error';
  static String printerChosen(String name) => '$name dipilih sebagai printer struk.';
  static String bluetoothDevicesCount(int count) => 'Perangkat Bluetooth ($count ter-pair)';
  static String paperWidthHint(String count) => '$count karakter per baris. Kebanyakan printer kasir kecil memakai 58 mm.';
  static String printerDetail(String address, String width) => '$address · $width mm';
  static String cannotConnectToPrinter(String name) => 'Tidak bisa terhubung ke $name. Pastikan printer menyala dan dekat.';
  static String receiptPhoneLine(String phone) => 'Telp $phone';
  static String receiptPercentDiscount(String value) => 'Diskon $value%';
  static String receiptTaxLine(String taxLabel, String rate) => '$taxLabel $rate%';
  static String receiptReceivablePayment(String date) => 'Pelunasan $date';
  static String receiptNote(String note) => 'Catatan: $note';
  static String printedAtLabel(String value) => 'Dicetak $value';
}

abstract final class OfflineStrings {
  // Layar mode offline
  static const title = 'Mode offline';
  static const connected = 'Terhubung ke Server';
  static const notReachable = 'Server Tidak Terjangkau';
  static const onlineBadge = 'Online';
  static const offlineBadge = 'Offline';
  static const connectedDescription = 'Transaksi kasir langsung tersinkronisasi otomatis ke server.';
  static const offlineDescription = 'Kasir tetap bisa berjualan. Transaksi disimpan di HP lalu dikirim otomatis saat online.';
  static const catalogHeader = 'KATALOG DI PERANGKAT';
  static const productsStoredLabel = 'Produk tersimpan';
  static const noProducts = 'Belum ada';
  static const lastUpdatedLabel = 'Terakhir diperbarui';
  static const catalogAutoUpdateHint = 'Diperbarui otomatis tiap 30 menit selama online agar harga dan stok tetap akurat.';
  static const refreshCatalogButton = 'Perbarui Katalog Sekarang';
  static const sendAllButton = 'Kirim Semua';
  static const allSentTitle = 'Semua transaksi sudah terkirim';
  static const allSentDescription = 'Tidak ada antrean transaksi offline yang tertunda.';

  // Aksi & dialog
  static const noSyncableTransactions = 'Tidak ada transaksi yang bisa dikirim.';
  static const serverStillUnreachable = 'Server masih belum terjangkau.';
  static const replaceCartTitle = 'Ganti isi keranjang?';
  static const replaceCartMessage = 'Keranjang kasir sekarang akan diganti dengan transaksi ini.';
  static const replaceCartConfirm = 'Ganti';
  static const recheckCartMessage = 'Periksa keranjang lalu bayar ulang. Uang yang sudah diterima tetap dihitung.';
  static const deleteOfflineSaleTitle = 'Hapus transaksi offline?';
  static const deleteConfirm = 'Hapus';
  static const statusRejected = 'Ditolak Server';
  static const statusWaiting = 'Menunggu Kirim';
  static const openInCart = 'Buka di keranjang';
  static const deleteTransaction = 'Hapus transaksi';
  static const bannerOffline = 'Offline — menampilkan data terakhir di perangkat';

  // Checkout offline sukses
  static const savedOnDeviceTitle = 'Tersimpan di perangkat';
  static const savedOnDeviceMessage = 'Server tidak terjangkau. Transaksi dikirim otomatis begitu koneksi kembali.';
  static const changeLabel = 'Kembalian';
  static const printReceiptButton = 'Cetak Struk';
  static const newTransactionButton = 'Transaksi Baru';

  static String productsSavedMessage(int count) => '$count produk tersimpan di perangkat.';
  static String syncResultMessage(int sent, int left) => left > 0 ? '$sent transaksi terkirim. $left masih menunggu.' : '$sent transaksi terkirim.';
  static String deleteOfflineSaleMessage(String total) =>
      'Transaksi $total tidak akan pernah tercatat di server. Pastikan uangnya sudah dikembalikan atau dicatat ulang.';
  static String queueHeader(int count) => 'Antrean Transaksi ($count)';
  static String lastSyncAttempt(String time) => 'Percobaan sinkronisasi terakhir $time';
  static String failedSalesMessage(int count) => '$count transaksi ditolak server. Buka di keranjang kasir untuk diperbaiki atau hapus.';
  static String itemsCount(String count) => '$count barang';
  static String sendingTransactions(int count) => 'Mengirim $count transaksi…';
  static String waitingTransactions(int count) => '$count transaksi menunggu dikirim';
}

abstract final class LegalStrings {
  static const privacyPolicy = 'Kebijakan Privasi';
  static const termsOfService = 'Ketentuan Layanan';
  static const registerAgreement = 'Dengan mendaftar, Anda menyetujui ';
  static const bulletSeparator = '•';
  static const andSeparator = ' & ';
}

abstract final class AboutStrings {
  static const logoText = 'KT';
  static const appName = 'Kasir Toko POS';
  static String versionBadge(String version, String buildNumber) => 'v$version (Build $buildNumber)';
  static const tagline = 'Sistem Operasional Kasir';
  static const privacyTitle = 'Kebijakan Privasi';
  static const privacySubtitle = 'Penggunaan kamera, bluetooth & data';
  static const termsTitle = 'Ketentuan Layanan & EULA';
  static const termsSubtitle = 'Lisensi penggunaan & aturan kasir';
  static const deleteAccountTitle = 'Penghapusan Akun & Data';
  static const deleteAccountSubtitle = 'Informasi hak hapus data pengguna';
  static String copyright(int year) => '© $year Kasir Toko POS. Hak Cipta Dilindungi.';
}

abstract final class ProStrings {
  static const exclusiveBadge = 'PRO';
  static const upgradeTitle = 'Fitur Khusus Paket Pro';
  static const upgradeDescription =
      'Fitur ini eksklusif untuk toko dengan paket Pro. Nikmati pengelolaan piutang pelanggan, laporan analisis mendalam, serta fitur profesional lainnya.';
  static const upgradeHowTo =
      'Untuk mengaktifkan fitur ini, silakan upgrade paket toko melalui dashboard web Kasir Toko.';
  static const actionUnderstood = 'Mengerti';
  static const subscriptionMenuLabel = 'Paket & Langganan';
  static const subscriptionMenuCaption = 'Status langganan & tambah masa aktif';
  static const subscriptionStatusTitle = 'Status Langganan Toko';
  static const planFreeLabel = 'Paket Gratis';
  static const planTrialLabel = 'Trial Pro 14 Hari';
  static const planProLabel = 'Paket Pro Aktif';
  static const actionUpgradeOrExtend = 'Kelola / Perpanjang';
}

