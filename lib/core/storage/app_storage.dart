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
  static const themeMode = 'theme_mode';
}
