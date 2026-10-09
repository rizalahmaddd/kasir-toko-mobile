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
  static const authCurrentOutlet = 'auth/current-outlet';

  // Outlet
  static const outlets = 'outlets';
  static const outletPriorities = 'outlets/priorities';
  static String outlet(int id) => 'outlets/$id';
  static String outletPrimary(int id) => 'outlets/$id/primary';
  static String outletActive(int id) => 'outlets/$id/active';
  static String outletUsers(int id) => 'outlets/$id/users';
  static String outletCopy(int id) => 'outlets/$id/copy';
  static String outletSettings(int id) => 'outlets/$id/settings';
  static String outletCapabilities(int id) => 'outlets/$id/capabilities';

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

  // Farmasi
  static String posProductSerials(int id) => 'pos/products/$id/serials';
  static const orders = 'orders';
  static String order(int id) => 'orders/$id';
  static String orderPayments(int id) => 'orders/$id/payments';
  static String orderStatus(int id) => 'orders/$id/status';
  static String orderCancel(int id) => 'orders/$id/cancel';
  static String orderCart(int id) => 'orders/$id/cart';
  static String saleDeliveryNotes(int saleId) => 'sales/$saleId/delivery-notes';
  static String deliveryNoteDelivered(int id) => 'delivery-notes/$id/delivered';
  static const prescriptions = 'pharmacy/prescriptions';
  static String prescription(int id) => 'pharmacy/prescriptions/$id';
  static String prescriptionVerify(int id) => 'pharmacy/prescriptions/$id/verify';
  static String prescriptionCancel(int id) => 'pharmacy/prescriptions/$id/cancel';
  static String prescriptionImage(int id) => 'pharmacy/prescriptions/$id/image';
  static String productBatches(int productId) => 'inventory/products/$productId/batches';

  // Stok opname
  static const stockCounts = 'inventory/stock-counts';
  static String stockCount(int id) => 'inventory/stock-counts/$id';
  static String stockCountItems(int id) => 'inventory/stock-counts/$id/items';
  static String stockCountItem(int id, int itemId) => 'inventory/stock-counts/$id/items/$itemId';
  static String stockCountItemEntries(int id, int itemId) => 'inventory/stock-counts/$id/items/$itemId/entries';
  static String stockCountCatalog(int id) => 'inventory/stock-counts/$id/catalog';
  static String stockCountLookup(int id) => 'inventory/stock-counts/$id/lookup';
  static String stockCountEntries(int id) => 'inventory/stock-counts/$id/entries';
  static String stockCountEntry(int id, int entryId) => 'inventory/stock-counts/$id/entries/$entryId';
  static String stockCountSerials(int id) => 'inventory/stock-counts/$id/serials';
  static String stockCountUnknown(int id) => 'inventory/stock-counts/$id/unknown';
  static String stockCountSubmit(int id) => 'inventory/stock-counts/$id/submit';
  static String stockCountReopen(int id) => 'inventory/stock-counts/$id/reopen';
  static String stockCountPreview(int id) => 'inventory/stock-counts/$id/preview';
  static String stockCountPost(int id) => 'inventory/stock-counts/$id/post';
  static String stockCountCancel(int id) => 'inventory/stock-counts/$id/cancel';
  static const expiringStock = 'inventory/expiring';

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
  static const outletsPrefix = 'outlets';
}
