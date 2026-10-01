import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
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
    final body = await _api.post('auth/login', data: {'login': login, 'password': password, 'device_name': deviceName});
    final data = ApiClient.data(body);
    final user = CurrentUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;

    await _secure.write(key: StorageKeys.token, value: token);
    await cacheUser(user);

    return (token: token, user: user);
  }

  Future<CurrentUser> me() async {
    final user = CurrentUser.fromJson(ApiClient.data(await _api.get('auth/me')));
    await cacheUser(user);

    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post('auth/logout');
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
