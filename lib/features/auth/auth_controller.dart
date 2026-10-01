import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
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
    ref.read(authTokenProvider.notifier).set(result.token);
    state = AsyncData(result.user);
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

  Future<void> _refreshProfile() async {
    try {
      final user = await _repository.me();
      state = AsyncData(user);
    } on ApiException {
      // Offline at startup is fine: keep the cached profile; a 401 is handled by expire().
    }
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
