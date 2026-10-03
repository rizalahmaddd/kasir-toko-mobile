import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/api_endpoints.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
import 'auth_config.dart';
import 'current_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

class StoredSession {
  const StoredSession(this.token, this.user);

  final String token;
  final CurrentUser? user;
}

class AuthRepository {
  AuthRepository(this._api, this._secure, this._prefs);

  final ApiClient _api;
  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  Future<({String token, CurrentUser user})> login({
    required String login,
    required String password,
    required String deviceName,
  }) async {
    final body = await _api.post(ApiEndpoints.authLogin, data: {'login': login, 'password': password, 'device_name': deviceName});
    return _storeSession(ApiClient.data(body));
  }

  Future<({String token, CurrentUser user})> register({
    required String shopName,
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
    required String deviceName,
  }) async {
    final body = await _api.post(ApiEndpoints.authRegister, data: {
      'shop_name': shopName,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': password,
      'device_name': deviceName,
    });
    return _storeSession(ApiClient.data(body));
  }

  Future<({String token, CurrentUser user})> _storeSession(Map<String, dynamic> data) async {
    final user = CurrentUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;

    await _secure.write(key: StorageKeys.token, value: token);
    await cacheUser(user);

    return (token: token, user: user);
  }

  Future<({String otpToken, String maskedPhone, int cooldown})> sendOtp(String login) async {
    final data = ApiClient.data(await _api.post(ApiEndpoints.authOtpSend, data: {'login': login}));

    return (
      otpToken: data['otp_token'] as String,
      maskedPhone: data['masked_phone'] as String? ?? '',
      cooldown: (data['cooldown_seconds'] as num?)?.toInt() ?? 60,
    );
  }

  Future<({String token, CurrentUser user})> verifyOtp({required String otpToken, required String otp, required String deviceName}) async {
    final body = await _api.post(ApiEndpoints.authOtpVerify, data: {'otp_token': otpToken, 'otp': otp, 'device_name': deviceName});
    return _storeSession(ApiClient.data(body));
  }

  Future<AuthConfig> getAuthConfig() async {
    try {
      final body = await _api.get(ApiEndpoints.authConfig);
      return AuthConfig.fromJson(ApiClient.data(body));
    } catch (_) {
      return AuthConfig.empty;
    }
  }

  Future<({String token, CurrentUser user})> loginWithGoogle({
    required String idToken,
    String? shopName,
    required String deviceName,
  }) async {
    final body = await _api.post(ApiEndpoints.authGoogle, data: {
      'id_token': idToken,
      if (shopName != null && shopName.isNotEmpty) 'shop_name': shopName,
      'device_name': deviceName,
    });
    return _storeSession(ApiClient.data(body));
  }

  Future<({String token, CurrentUser user})> loginWithApple({
    required String identityToken,
    String? name,
    String? shopName,
    required String deviceName,
  }) async {
    final body = await _api.post(ApiEndpoints.authApple, data: {
      'identity_token': identityToken,
      if (name != null && name.isNotEmpty) 'name': name,
      if (shopName != null && shopName.isNotEmpty) 'shop_name': shopName,
      'device_name': deviceName,
    });
    return _storeSession(ApiClient.data(body));
  }

  Future<void> deleteAccount() async {
    try {
      await _api.delete(ApiEndpoints.authAccount);
    } finally {
      await clear();
    }
  }

  Future<CurrentUser> updateProfile({required String name, required String username, required String email, String? phone}) async {
    final body = await _api.put(ApiEndpoints.authProfile, data: {'name': name, 'username': username, 'email': email, 'phone': phone});
    final user = CurrentUser.fromJson(ApiClient.data(body));
    await cacheUser(user);

    return user;
  }

  Future<void> updatePassword({required String current, required String password, required bool revokeOthers}) =>
      _api.put(
        ApiEndpoints.authPassword,
        data: {'current_password': current, 'password': password, 'password_confirmation': password, 'revoke_other_tokens': revokeOthers},
      );

  Future<void> logoutAll() async {
    try {
      await _api.post(ApiEndpoints.authLogoutAll);
    } finally {
      await clear();
    }
  }

  Future<CurrentUser> me() async {
    final user = CurrentUser.fromJson(ApiClient.data(await _api.get(ApiEndpoints.authMe)));
    await cacheUser(user);

    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.authLogout);
    } finally {
      await clear();
    }
  }

  Future<StoredSession?> restore() async {
    final token = await _secure.read(key: StorageKeys.token);
    if (token == null) {
      return null;
    }

    final cached = _prefs.getString(StorageKeys.user);
    final user = cached == null ? null : CurrentUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);

    return StoredSession(token, user);
  }

  Future<void> cacheUser(CurrentUser user) => _prefs.setString(StorageKeys.user, jsonEncode(user.toJson()));

  Future<void> clear() async {
    await _secure.delete(key: StorageKeys.token);
    await _prefs.remove(StorageKeys.user);
  }
}
