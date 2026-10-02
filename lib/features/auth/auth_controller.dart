import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/offline/offline_cache.dart';
import '../../core/storage/app_storage.dart';
import '../pos/cart_controller.dart';
import 'data/auth_repository.dart';
import 'data/current_user.dart';

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
    ref.read(authTokenProvider.notifier).set(null);
    state = const AsyncData(null);
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } on ApiException {
      // The token is dropped locally either way; a failed revoke only leaves it on the server.
    }
    ref.read(authTokenProvider.notifier).set(null);
    state = const AsyncData(null);
  }

  /// Token revoked or expired on the server.
  Future<void> expire() async {
    if (state.value == null) {
      return;
    }
    await _forget();
    state = const AsyncData(null);
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

    if (tenantId != null && prefs.getInt(StorageKeys.lastTenant) != tenantId) {
      await prefs.remove(StorageKeys.cart);
      await ref.read(offlineCacheProvider).clear();
      await prefs.setInt(StorageKeys.lastTenant, tenantId);
      ref.invalidate(cartProvider);
    }

    ref.read(authTokenProvider.notifier).set(token);
    state = AsyncData(user);
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
