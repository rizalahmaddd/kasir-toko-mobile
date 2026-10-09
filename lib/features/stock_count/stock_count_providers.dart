import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/paging/paged.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/formatters.dart';
import '../outlets/outlet_controller.dart';
import 'count_queue.dart';
import 'data/stock_count_models.dart';
import 'data/stock_count_repository.dart';

final stockCountsTabProvider = NotifierProvider<QueryNotifier<String>, String>(() => QueryNotifier('open'));

final stockCountsProvider = AsyncNotifierProvider<StockCountsNotifier, PagedState<StockCountDoc>>(StockCountsNotifier.new);

class StockCountsNotifier extends PagedNotifier<StockCountDoc> {
  @override
  Future<Paginated<StockCountDoc>> fetch(int page) {
    ref.watch(currentOutletIdProvider);
    return ref.read(stockCountRepositoryProvider).list(status: ref.watch(stockCountsTabProvider), page: page);
  }
}

final stockCountProvider = FutureProvider.autoDispose.family<StockCountDoc, int>((ref, id) => ref.read(stockCountRepositoryProvider).show(id));

/// Opname yang berjalan di outlet aktif, untuk banner di layar Stok.
final openStockCountsProvider = FutureProvider.autoDispose<List<StockCountDoc>>((ref) async {
  ref.watch(currentOutletIdProvider);
  try {
    return (await ref.read(stockCountRepositoryProvider).list()).items;
  } on ApiException {
    return const [];
  }
});

/// Nomor opname berjalan per produk, untuk badge "Sedang dihitung" di layar Stok. Opname "Semua barang"
/// berlaku untuk semua produk lewat kunci `null`.
final countingProductsProvider = FutureProvider.autoDispose<Map<int?, String>>((ref) async {
  final open = await ref.watch(openStockCountsProvider.future);
  final result = <int?, String>{};
  for (final count in open) {
    if (count.scope == 'all') {
      result[null] ??= count.number;
      continue;
    }
    final catalog = await ref.watch(countCatalogProvider(count.id).future).catchError((_) => null);
    for (final item in catalog?.items ?? const <CountCatalogItem>[]) {
      result[item.productId] ??= count.number;
    }
  }
  return result;
});

/// Daftar barang opname untuk scan tanpa sinyal: diunduh saat online dan disimpan di HP.
final countCatalogProvider = FutureProvider.autoDispose.family<CountCatalog?, int>((ref, id) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final key = '${StorageKeys.stockCountCatalogPrefix}$id';
  try {
    final catalog = await ref.read(stockCountRepositoryProvider).catalog(id);
    await prefs.setString(key, jsonEncode({'scope_all': catalog.scopeAll, 'items': catalog.items.map((item) => item.toJson()).toList()}));
    return catalog;
  } on ApiException catch (error) {
    if (!error.isNetworkError) {
      rethrow;
    }
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CountCatalog((json['items'] as List).cast<Map<String, dynamic>>().map(CountCatalogItem.fromJson).toList(), scopeAll: json['scope_all'] == true);
  }
});

const _uuid = Uuid();

/// Jumlah dalam satuan dasar dari rincian per satuan; null = satuan dasar.
double baseQuantity(Map<int?, double> lines, List<CountUnit> units) {
  var total = 0.0;
  for (final MapEntry(key: unitId, value: amount) in lines.entries) {
    final factor = unitId == null ? 1.0 : units.firstWhere((unit) => unit.id == unitId, orElse: () => CountUnit(id: unitId, name: '', factor: 1)).factor;
    total += amount * factor;
  }
  return double.parse(total.toStringAsFixed(3));
}

/// Satu hitungan siap masuk antrean. Satu baris rincian dikirim sebagai quantity + unit_id; lebih dari
/// satu sebagai breakdown, supaya riwayat di web menampilkan "2 dus + 5 pcs".
QueuedCount countEntry({
  required int countId,
  required int userId,
  required CountCatalogItem item,
  required Map<int?, double> lines,
  int? batchId,
  String? newBatchNumber,
  String? newBatchExpiry,
  String? note,
  DateTime? countedAt,
  int? outletId,
}) {
  final nonEmpty = {for (final entry in lines.entries) if (entry.value >= 0) entry.key: entry.value};
  final payload = <String, dynamic>{
    'product_id': item.productId,
    'counted_at': (countedAt ?? DateTime.now()).toUtc().toIso8601String(),
    if (nonEmpty.length == 1) ...{'quantity': nonEmpty.values.first, 'unit_id': nonEmpty.keys.first},
    if (nonEmpty.length > 1) 'breakdown': [for (final entry in nonEmpty.entries) {'unit_id': entry.key, 'quantity': entry.value}],
    'product_batch_id': ?batchId,
    if (newBatchNumber != null && newBatchNumber.trim().isNotEmpty) 'new_batch': {'number': newBatchNumber.trim(), 'expires_at': newBatchExpiry},
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
  };
  final parts = [
    for (final entry in nonEmpty.entries)
      '${quantity(entry.value)} ${entry.key == null ? item.unit : item.units.firstWhere((unit) => unit.id == entry.key, orElse: () => CountUnit(id: 0, name: item.unit, factor: 1)).name}',
  ];

  return QueuedCount(
    kind: CountKind.entry,
    countId: countId,
    clientUuid: _uuid.v4(),
    userId: userId,
    payload: payload,
    label: '${item.name} · ${parts.join(' + ')}',
    createdAt: DateTime.now(),
    outletId: outletId,
  );
}

QueuedCount serialScan({required int countId, required int userId, required String serial, int? productId, String? productName, int? outletId}) =>
    QueuedCount(
      kind: CountKind.serial,
      countId: countId,
      clientUuid: _uuid.v4(),
      userId: userId,
      payload: {'serial': serial.trim().toUpperCase(), 'product_id': ?productId, 'scanned_at': DateTime.now().toUtc().toIso8601String()},
      label: [?productName, serial.trim().toUpperCase()].join(' · '),
      createdAt: DateTime.now(),
      outletId: outletId,
    );
