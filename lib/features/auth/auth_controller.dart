import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/offline/offline_cache.dart';
import '../../core/storage/app_storage.dart';
import '../data_changes.dart';
import 'data/auth_config.dart';
import 'data/auth_repository.dart';
import 'data/current_user.dart';

final authConfigProvider = FutureProvider.autoDispose<AuthConfig>((ref) async {
  return ref.watch(authRepositoryProvider).getAuthConfig();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, CurrentUser?>(AuthController.new);

final currentUserProvider = Provider<CurrentUser?>((ref) => ref.watch(authControllerProvider).value);

class AuthController extends AsyncNotifier<CurrentUser?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<CurrentUser?> build() async {
    final session = await _repository.restore();
    if (session == null) {
      return null;
    }

    ref.read(authTokenProvider.notifier).set(session.token);

    if (session.user != null) {
      unawaited(_refreshProfile());
      return session.user;
    }

    try {
      return await _repository.me();
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        await _forget();
        await _clearTenantStorage();
        ref.read(dataChangesProvider).resetAllSessionData();
        return null;
      }
      rethrow;
    }
  }

  Future<void> login({required String login, required String password}) async {
    final result = await _repository.login(login: login, password: password, deviceName: _deviceName());
    await _start(result.token, result.user);
  }

  Future<void> register({
    required String shopName,
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) async {
    final result = await _repository.register(
      shopName: shopName,
      name: name,
      username: username,
      email: email,
      phone: phone,
      password: password,
      deviceName: _deviceName(),
    );
    await _start(result.token, result.user);
  }

  Future<({String otpToken, String maskedPhone, int cooldown})> sendOtp(String login) => _repository.sendOtp(login);

  Future<void> verifyOtp({required String otpToken, required String otp}) async {
    final result = await _repository.verifyOtp(otpToken: otpToken, otp: otp, deviceName: _deviceName());
    await _start(result.token, result.user);
  }

  Future<void> updateProfile({required String name, required String username, required String email, String? phone}) async {
    state = AsyncData(await _repository.updateProfile(name: name, username: username, email: email, phone: phone));
  }

  Future<void> logoutAll() async {
    try {
      await _repository.logoutAll();
    } on ApiException {
      // Same as logout(): the local session ends regardless.
    }
    await _clearTenantStorage();
    ref.read(authTokenProvider.notifier).set(null);
    state = const AsyncData(null);
    ref.read(dataChangesProvider).resetAllSessionData();
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } on ApiException {
      // The token is dropped locally either way; a failed revoke only leaves it on the server.
    }
    await _clearTenantStorage();
    ref.read(authTokenProvider.notifier).set(null);
    state = const AsyncData(null);
    ref.read(dataChangesProvider).resetAllSessionData();
  }

  Future<void> signInWithGoogle({String? shopName}) async {
    final config = await ref.read(authConfigProvider.future);
    final googleSignIn = GoogleSignIn(
      serverClientId: config.googleClientId,
      scopes: const ['email', 'profile'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      return; // Canceled by user
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw ApiException(message: AuthStrings.googleAuthTokenFailed);
    }

    final result = await _repository.loginWithGoogle(
      idToken: idToken,
      shopName: shopName,
      deviceName: _deviceName(),
    );
    await _start(result.token, result.user);
  }

  Future<void> signInWithApple({String? shopName}) async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw ApiException(message: AuthStrings.appleAuthTokenFailed);
      }

      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        fullName = [credential.givenName, credential.familyName]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
      }

      final result = await _repository.loginWithApple(
        identityToken: identityToken,
        name: fullName,
        shopName: shopName,
        deviceName: _deviceName(),
      );
      await _start(result.token, result.user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return; // Canceled by user
      }
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    await _clearTenantStorage();
    ref.read(authTokenProvider.notifier).set(null);
    state = const AsyncData(null);
    ref.read(dataChangesProvider).resetAllSessionData();
  }

  /// Token revoked or expired on the server.
  Future<void> expire() async {
    if (state.value == null) {
      return;
    }
    await _forget();
    await _clearTenantStorage();
    state = const AsyncData(null);
    ref.read(dataChangesProvider).resetAllSessionData();
  }

  /// The server answered 402: show the blocked screen until the shop is reactivated.
  void markBlocked(String reason, String message) {
    final user = state.value;
    final tenant = user?.tenant;
    if (user == null || tenant == null || tenant.blockedReason == reason) {
      return;
    }
    state = AsyncData(user.withTenant(tenant.blocked(reason, message: message.isEmpty ? null : message)));
  }

  /// Takes the shop state from a response that already carries it, then re-reads the profile
  /// because the enabled features may have changed with it.
  Future<void> updateTenant(TenantInfo tenant) async {
    final user = state.value;
    if (user == null) {
      return;
    }
    final updated = user.withTenant(tenant);
    await _repository.cacheUser(updated);
    state = AsyncData(updated);
    await _refreshProfile();
  }

  /// Re-reads the profile, e.g. after the shop owner renewed the subscription.
  Future<void> refreshProfile() => _refreshProfile();

  Future<void> _refreshProfile() async {
    try {
      final user = await _repository.me();
      state = AsyncData(user);
    } on ApiException {
      // Offline at startup is fine: keep the cached profile; a 401 is handled by expire().
    }
  }

  /// A cart or cached catalog from another shop on this device must not leak into this one.
  Future<void> _start(String token, CurrentUser user) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final tenantId = user.tenant?.id;
    final lastTenant = prefs.getInt(StorageKeys.lastTenant);

    if (lastTenant != null && lastTenant != tenantId) {
      await _clearTenantStorage();
    }

    if (tenantId != null) {
      await prefs.setInt(StorageKeys.lastTenant, tenantId);
    }

    ref.read(authTokenProvider.notifier).set(token);
    state = AsyncData(user);

    // Reset all in-memory providers across all features so no stale data from any
    // prior session/tenant is retained.
    ref.read(dataChangesProvider).resetAllSessionData();
  }

  Future<void> _clearTenantStorage() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(StorageKeys.cart);
    await prefs.remove(StorageKeys.receiptProfile);
    await prefs.remove(StorageKeys.storeName);
    await prefs.remove(StorageKeys.lastTenant);
    await OfflineCache.clearStorage(prefs);
  }

  Future<void> _forget() async {
    await _repository.clear();
    ref.read(authTokenProvider.notifier).set(null);
  }

  String _deviceName() {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      _ => defaultTargetPlatform.name,
    };
    return 'Kasir Toko Mobile ($platform)';
  }
}
