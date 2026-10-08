import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

abstract final class StorageKeys {
  static const token = 'auth_token';
  static const user = 'auth_user';
  static const serverUrl = 'server_url';
  static const cart = 'pos_cart';
  static const lastTenant = 'last_tenant_id';
  static const currentOutletPrefix = 'current_outlet_';
  static const themeMode = 'theme_mode';

  static const storeName = 'store_name';
  static const receiptProfile = 'receipt_profile';
  static const catalog = 'catalog';

  /// The catalog carries prices and stock of one outlet, so every outlet keeps its own copy.
  static String catalogFor(int? outletId) => outletId == null ? catalog : '${catalog}_$outletId';
  static const offlineSalesQueue = 'offline_sales_queue';
  static const stockCountQueue = 'stock_count_queue';
  static const stockCountCatalogPrefix = 'stock_count_catalog_';
  static const offlineCachePrefix = 'offline_cache_';
  static const catalogDensity = 'pos_catalog_density';
  static const posKeepScreenOn = 'pos_keep_screen_on';
  static const posQrFullBrightness = 'pos_qr_full_brightness';
}
