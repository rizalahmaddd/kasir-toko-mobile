/// Path endpoint API. Path statis berupa konstanta, path berparameter
/// berupa fungsi pembentuk.
abstract final class ApiEndpoints {
  // Auth
  static const authLogin = 'auth/login';
  static const authRegister = 'auth/register';
  static const authOtpSend = 'auth/otp/send';
  static const authOtpVerify = 'auth/otp/verify';
  static const authConfig = 'auth/config';
  static const authGoogle = 'auth/google';
  static const authApple = 'auth/apple';
  static const authAccount = 'auth/account';
  static const authProfile = 'auth/profile';
  static const authPassword = 'auth/password';
  static const authLogoutAll = 'auth/logout-all';
  static const authMe = 'auth/me';
  static const authLogout = 'auth/logout';

  // Umum
  static const dashboard = 'dashboard';
  static const meta = 'meta';
  static const search = 'search';

  // Notifikasi
  static const notifications = 'notifications';
  static const notificationsUnreadCount = 'notifications/unread-count';
  static const notificationsReadAll = 'notifications/read-all';
  static String notificationRead(String id) => 'notifications/$id/read';

  // Onboarding
  static const onboardingPresets = 'onboarding/presets';
  static const onboardingApply = 'onboarding/apply';
  static const onboardingSkip = 'onboarding/skip';

  // Master data - produk
  static const products = 'master-data/products';
  static String product(int id) => 'master-data/products/$id';
  static String productImage(int id) => 'master-data/products/$id/image';

  // Master data - kategori
  static const categories = 'master-data/categories';
  static String category(int id) => 'master-data/categories/$id';

  // Master data - pelanggan
  static const customers = 'master-data/customers';
  static String customer(int id) => 'master-data/customers/$id';

  // Transaksi
  static String sale(int id) => 'sales/$id';
  static String saleReceipt(int id) => 'sales/$id/receipt';
  static String saleVoid(int id) => 'sales/$id/void';

  // Piutang
  static const receivables = 'receivables';
  static String receivablePayments(int saleId) => 'receivables/$saleId/payments';

  // Laporan
  static const reportsSalesSummary = 'reports/sales/summary';
  static const reportsSalesDaily = 'reports/sales/daily';
  static const reportsSalesProducts = 'reports/sales/products';
  static const reportsActivityLog = 'reports/activity-log';

  // Shift
  static const posShift = 'pos/shift';
  static const posShiftCashMovements = 'pos/shift/cash-movements';
  static const shifts = 'shifts';
  static String shift(int id) => 'shifts/$id';
  static String shiftSales(int id) => 'shifts/$id/sales';
  static String shiftCashMovements(String shiftId) => 'shifts/$shiftId/cash-movements';
  static String shiftClose(String shiftId) => 'shifts/$shiftId/close';

  // POS
  static const posConfig = 'pos/config';
  static const posSettings = 'pos/settings';
  static const posCategories = 'pos/categories';
  static const posProducts = 'pos/products';
  static const posProductsLookup = 'pos/products/lookup';
  static const posCustomers = 'pos/customers';
  static const posQris = 'pos/qris';
  static const posCheckout = 'pos/checkout';
  static const posHeldOrders = 'pos/held-orders';
  static String posHeldOrderResume(int id) => 'pos/held-orders/$id/resume';
  static String posHeldOrder(int id) => 'pos/held-orders/$id';

  // Prefiks untuk aturan cache
  static const posPrefix = 'pos/';
  static const authPrefix = 'auth/';
}
