/// Semua path route aplikasi. Path statis berupa konstanta, path
/// berparameter memakai pola (:id) untuk `GoRoute` dan fungsi pembentuk
/// untuk navigasi.
abstract final class AppRoutes {
  // Root & auth
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const blocked = '/blocked';
  static const onboarding = '/onboarding';

  // Shell branch
  static const dashboard = '/dashboard';
  static const pos = '/pos';
  static const sales = '/sales';
  static const products = '/products';
  static const menu = '/menu';

  // Produk
  static const product = '/product';
  static const productNew = '/product/new';
  static const productPattern = '/product/:id';
  static const productEditPattern = '/product/:id/edit';
  static const categories = '/categories';

  // Stok
  static const stock = '/stock';
  static const stockMovements = '/stock/movements';

  // Pelanggan
  static const customers = '/customers';
  static const customer = '/customer';
  static const customerNew = '/customer/new';
  static const customerPattern = '/customer/:id';
  static const customerEditPattern = '/customer/:id/edit';

  // Transaksi & piutang
  static const sale = '/sale';
  static const salePattern = '/sale/:id';
  static const receivables = '/receivables';

  // Shift
  static const shift = '/shift';
  static const shifts = '/shifts';
  static const shiftPattern = '/shift/:id';

  // Lain-lain
  static const reports = '/reports';
  static const reportsSales = '/reports/sales';
  static const activity = '/activity';
  static const notifications = '/notifications';
  static const search = '/search';
  static const account = '/account';
  static const printer = '/printer';
  static const posSettings = '/pos-settings';
  static const offline = '/offline';
  static const editSuffix = '/edit';

  static String saleDetail(int id) => '$sale/$id';
  static String productDetail(int id) => '$product/$id';
  static String productEdit(int id) => '$product/$id/edit';
  static String customerDetail(int id) => '$customer/$id';
  static String customerEdit(int id) => '$customer/$id/edit';
  static String shiftDetail(int id) => '$shift/$id';
  static String stockMovementsFor(int productId, String name) =>
      '$stockMovements?product=$productId&name=${Uri.encodeComponent(name)}';
}
