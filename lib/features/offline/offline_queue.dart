import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/json.dart';
import '../auth/access.dart';
import '../auth/auth_controller.dart';
import '../pos/data/pos_repository.dart';
import '../pos/pos_providers.dart';
import '../sales/sales_controller.dart';
import '../shift/shift_controller.dart';
import 'catalog_snapshot.dart';

enum QueuedStatus { pending, failed }

/// A sale paid for while the server was unreachable, waiting to be sent with its original client_uuid.
class QueuedSale {
  const QueuedSale({
    required this.payload,
    required this.cart,
    required this.userId,
    required this.total,
    required this.paid,
    required this.itemCount,
    required this.createdAt,
    this.customerName,
    this.preview = const {},
    this.status = QueuedStatus.pending,
    this.error,
  });

  factory QueuedSale.fromJson(Map<String, dynamic> json) => QueuedSale(
        payload: asMap(json['payload']),
        cart: asMap(json['cart']),
        userId: asInt(json['user_id']),
        total: asInt(json['total']),
        paid: asInt(json['paid']),
        itemCount: asDouble(json['item_count']),
        createdAt: DateTime.parse(json['created_at'] as String),
        customerName: json['customer_name'] as String?,
        preview: asMap(json['preview']),
        status: json['status'] == 'failed' ? QueuedStatus.failed : QueuedStatus.pending,
        error: json['error'] as String?,
      );

  final Map<String, dynamic> payload;
  final Map<String, dynamic> cart;
  final int userId;
  final int total;
  final int paid;
  final double itemCount;
  final DateTime createdAt;
  final String? customerName;

  /// SaleDetail-shaped copy built on the device, for printing a receipt before the server has the sale.
  final Map<String, dynamic> preview;
  final QueuedStatus status;
  final String? error;

  String get clientUuid => payload['client_uuid'] as String;
  int get change => paid > total ? paid - total : 0;

  QueuedSale copyWith({QueuedStatus? status, String? error}) => QueuedSale(
        payload: payload,
        cart: cart,
        userId: userId,
        total: total,
        paid: paid,
        itemCount: itemCount,
        createdAt: createdAt,
        customerName: customerName,
        preview: preview,
        status: status ?? this.status,
        error: error,
      );

  Map<String, dynamic> toJson() => {
        'payload': payload,
        'cart': cart,
        'user_id': userId,
        'total': total,
        'paid': paid,
        'item_count': itemCount,
        'created_at': createdAt.toIso8601String(),
        'customer_name': customerName,
        'preview': preview,
        'status': status.name,
        'error': error,
      };
}

class SyncState {
  const SyncState({this.syncing = false, this.lastSyncAt, this.lastSynced = 0});

  final bool syncing;
  final DateTime? lastSyncAt;
  final int lastSynced;
}

final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(SyncStateNotifier.new);

class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  void set(SyncState value) => state = value;
}

final offlineQueueProvider = NotifierProvider<OfflineQueue, List<QueuedSale>>(OfflineQueue.new);

/// Sales of the logged-in cashier still waiting for the server.
final myQueueProvider = Provider<List<QueuedSale>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  return ref.watch(offlineQueueProvider).where((sale) => sale.userId == userId).toList();
});

class OfflineQueue extends Notifier<List<QueuedSale>> {
  static const _key = 'offline_sales_queue';

  @override
  List<QueuedSale> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) {
      return const [];
    }
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(QueuedSale.fromJson).toList();
    } on Object {
      return const [];
    }
  }

  @override
  set state(List<QueuedSale> value) {
    super.state = value;
    ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(value.map((sale) => sale.toJson()).toList()));
  }

  void add(QueuedSale sale) => state = [...state, sale];

  void remove(String clientUuid) => state = state.where((sale) => sale.clientUuid != clientUuid).toList();

  void _update(String clientUuid, QueuedSale Function(QueuedSale) change) =>
      state = [for (final sale in state) sale.clientUuid == clientUuid ? change(sale) : sale];

  /// Sends queued sales oldest first. Stops at the first network failure; a business rejection
  /// marks that sale failed and moves on, since later sales don't depend on it.
  Future<int> sync({bool includeFailed = false}) async {
    final userId = ref.read(currentUserProvider)?.id;
    final syncState = ref.read(syncStateProvider.notifier);
    if (userId == null || ref.read(syncStateProvider).syncing) {
      return 0;
    }

    final due = state.where((sale) => sale.userId == userId && (includeFailed || sale.status == QueuedStatus.pending)).toList();
    if (due.isEmpty) {
      return 0;
    }

    syncState.set(SyncState(syncing: true, lastSyncAt: ref.read(syncStateProvider).lastSyncAt));
    var sent = 0;
    try {
      for (final sale in due) {
        try {
          await ref.read(posRepositoryProvider).submitCheckout(sale.payload);
          remove(sale.clientUuid);
          sent++;
        } on ApiException catch (error) {
          if (error.isNetworkError) {
            break;
          }
          if (error.isUnauthenticated) {
            break;
          }
          _update(sale.clientUuid, (s) => s.copyWith(status: QueuedStatus.failed, error: error.message));
        }
      }
    } finally {
      syncState.set(SyncState(lastSyncAt: DateTime.now(), lastSynced: sent));
      if (sent > 0) {
        ref
          ..invalidate(salesProvider)
          ..invalidate(currentShiftProvider)
          ..invalidate(catalogProvider);
      }
    }

    return sent;
  }
}

/// Retries queued sales when connectivity returns, when the app comes back to the foreground,
/// whenever a request reaches the server again, and every minute while anything is waiting.
final offlineSyncerProvider = Provider<void>((ref) {
  void trigger() {
    if (ref.read(myQueueProvider).any((sale) => sale.status == QueuedStatus.pending)) {
      unawaited(ref.read(offlineQueueProvider.notifier).sync());
    }
  }

  final connectivity = Connectivity().onConnectivityChanged.listen((results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      trigger();
    }
  });
  Future<void> refreshCatalog() async {
    if (!(ref.read(currentUserProvider)?.canSell ?? false)) {
      return;
    }
    final snapshot = await ref.read(catalogSnapshotProvider.future);
    if (snapshot == null || DateTime.now().difference(snapshot.updatedAt) > const Duration(minutes: 30)) {
      try {
        await ref.read(catalogSnapshotProvider.notifier).download();
      } on ApiException {
        // Offline or server error: keep the copy we have and try again on the next tick.
      }
    }
  }

  final lifecycle = AppLifecycleListener(
    onResume: () {
      trigger();
      unawaited(refreshCatalog());
    },
  );
  final timer = Timer.periodic(const Duration(minutes: 1), (_) => trigger());
  final catalogTimer = Timer.periodic(const Duration(minutes: 15), (_) => refreshCatalog());
  Future.microtask(refreshCatalog);
  ref.listen(serverReachableProvider, (previous, reachable) {
    if (reachable && previous == false) {
      trigger();
    }
  });
  Future.microtask(trigger);

  ref.onDispose(() {
    connectivity.cancel();
    lifecycle.dispose();
    timer.cancel();
    catalogTimer.cancel();
  });
});
