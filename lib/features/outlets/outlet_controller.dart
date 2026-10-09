import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/app_storage.dart';
import '../auth/auth_controller.dart';
import '../auth/data/current_user.dart';
import '../data_changes.dart';
import '../pos/cart_controller.dart';
import 'data/outlet_models.dart';
import 'data/outlet_repository.dart';

/// Outlet the app works in. It is sent as X-Outlet-Id on every request and decides which stock,
/// prices, shift and sales the screens show. Chosen per account and remembered on the device.
final currentOutletIdProvider = NotifierProvider<CurrentOutletId, int?>(CurrentOutletId.new);

class CurrentOutletId extends Notifier<int?> {
  static String storageKey(int userId) => '${StorageKeys.currentOutletPrefix}$userId';

  @override
  int? build() {
    final user = ref.watch(currentUserProvider);
    if (user == null || user.outlets.isEmpty) {
      return null;
    }

    return resolve(user, ref.read(sharedPreferencesProvider).getInt(storageKey(user.id)));
  }

  /// The saved choice while it can still sell, then the server's pick, then any outlet that can sell.
  static int? resolve(CurrentUser user, int? stored) {
    OutletInfo? usable(int? id) => user.outlets.where((outlet) => outlet.id == id && outlet.isOperational).firstOrNull;

    return usable(stored)?.id ?? usable(user.currentOutletId)?.id ?? user.outlets.where((outlet) => outlet.isOperational).firstOrNull?.id ?? user.outlets.firstOrNull?.id;
  }

  /// Switching drops the cart (its prices and stock belong to the old outlet) and reloads every screen.
  Future<void> select(int outletId) async {
    final user = ref.read(currentUserProvider);
    if (user == null || state == outletId || user.outletById(outletId) == null) {
      return;
    }

    ref.read(cartProvider.notifier).clear();
    await ref.read(sharedPreferencesProvider).setInt(storageKey(user.id), outletId);
    state = outletId;
    ref.read(dataChangesProvider).resetAllSessionData();
    unawaited(_remember(outletId));
  }

  Future<void> _remember(int outletId) async {
    try {
      await ref.read(outletRepositoryProvider).rememberCurrent(outletId);
    } on ApiException {
      // Only a hint for other devices; this device already works in the chosen outlet.
    }
  }
}

final currentOutletProvider = Provider<OutletInfo?>((ref) {
  final user = ref.watch(currentUserProvider);

  return user?.outletById(ref.watch(currentOutletIdProvider));
});

/// Outlet name for headers, only in shops with several outlets.
final outletLabelProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);

  return user != null && user.hasMultipleOutlets ? ref.watch(currentOutletProvider)?.name : null;
});

/// Every outlet of the shop with user counts, for the management screen.
final managedOutletsProvider = FutureProvider.autoDispose<List<OutletInfo>>((ref) => ref.watch(outletRepositoryProvider).list(all: true));

final outletAccessProvider = FutureProvider.autoDispose.family<List<OutletUser>, int>((ref, id) => ref.watch(outletRepositoryProvider).access(id));

final outletSettingsProvider = FutureProvider.autoDispose.family<OutletSettingsData, int>((ref, id) => ref.watch(outletRepositoryProvider).settings(id));
