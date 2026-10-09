import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../offline/catalog_snapshot.dart';
import 'product_models.dart';

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(ref.watch(apiClientProvider), () => ref.read(catalogSnapshotProvider.future)),
);

class ProductsRepository {
  ProductsRepository(this._api, [this._snapshot]);

  final ApiClient _api;
  final Future<CatalogSnapshot?> Function()? _snapshot;

  /// Offline, the catalog snapshot usually wins over a saved response: it answers any filter and
  /// already counts the sales made since. The saved response covers what the snapshot doesn't hold.
  Future<T> _read<T>(
    String path,
    Map<String, dynamic> query,
    T Function(dynamic body) parse,
    T? Function(CatalogSnapshot snapshot) local, {
    bool snapshotFirst = true,
  }) async {
    try {
      return parse(await _api.get(path, query: query, offlineCopy: false));
    } on ApiException catch (error) {
      if (!error.isNetworkError) {
        rethrow;
      }
      Future<T?> fromCopy() async {
        final copy = await _api.offlineCopy(path, query: query);
        return copy == null ? null : parse(copy);
      }

      Future<T?> fromSnapshot() async {
        final snapshot = await _snapshot?.call();
        return snapshot == null ? null : local(snapshot);
      }

      final result = snapshotFirst ? await fromSnapshot() ?? await fromCopy() : await fromCopy() ?? await fromSnapshot();
      return result ?? (throw ApiException.notCached());
    }
  }

  Future<Paginated<ProductRecord>> products({String? search, int? categoryId, String? status, String? sort, int page = 1}) => _read(
        ApiEndpoints.products,
        {'search': search, 'category_id': categoryId, 'status': status, 'sort': sort, 'page': page, 'per_page': 30},
        (body) => Paginated.fromJson(body, ProductRecord.fromJson),
        (snapshot) => snapshot.records(search: search, categoryId: categoryId, status: status, sort: sort, page: page),
      );

  Future<ProductRecord> product(int id) => _read(
        ApiEndpoints.product(id),
        const {},
        (body) => ProductRecord.fromJson(ApiClient.data(body)),
        (snapshot) => snapshot.record(id),
      );

  Future<ProductRecord?> getCached(int id) async {
    final snapshot = await _snapshot?.call();
    final localRecord = snapshot?.record(id);
    if (localRecord != null) {
      return localRecord;
    }
    final copy = await _api.offlineCopy(ApiEndpoints.product(id));
    if (copy == null) {
      return null;
    }
    try {
      return ProductRecord.fromJson(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<ProductRecord> saveProduct(ProductInput input, {int? id}) async {
    final body = id == null ? await _api.post(ApiEndpoints.products, data: input.toJson()) : await _api.put(ApiEndpoints.product(id), data: input.toJson());
    if (id != null) {
      await _api.updateCached(ApiEndpoints.product(id), body);
    }
    return ProductRecord.fromJson(ApiClient.data(body));
  }

  Future<void> deleteProduct(int id) async {
    await _api.delete(ApiEndpoints.product(id));
    await _api.removeCached(ApiEndpoints.product(id));
  }

  Future<ProductRecord> uploadImage(int id, String filePath) async =>
      ProductRecord.fromJson(ApiClient.data(await _api.upload(ApiEndpoints.productImage(id), field: 'image', filePath: filePath)));

  Future<ProductRecord> deleteImage(int id) async => ProductRecord.fromJson(ApiClient.data(await _api.delete(ApiEndpoints.productImage(id))));

  Future<Paginated<CategoryRecord>> categories({String? search, int page = 1, int perPage = 50}) => _read(
        ApiEndpoints.categories,
        {'search': search, 'page': page, 'per_page': perPage},
        (body) => Paginated.fromJson(body, CategoryRecord.fromJson),
        (snapshot) => (search ?? '').isEmpty && page == 1 ? Paginated(items: snapshot.categories(), currentPage: 1, lastPage: 1) : null,
        snapshotFirst: false,
      );

  /// [outletIds] empty opens the category to every outlet; null leaves the current choice untouched.
  Future<CategoryRecord> saveCategory({int? id, required String name, required int sortOrder, required bool isActive, List<int>? outletIds}) async {
    final data = {'name': name, 'sort_order': sortOrder, 'is_active': isActive, 'outlet_ids': ?outletIds};
    final body = id == null ? await _api.post(ApiEndpoints.categories, data: data) : await _api.put(ApiEndpoints.category(id), data: data);

    return CategoryRecord.fromJson(ApiClient.data(body));
  }

  Future<void> deleteCategory(int id) => _api.delete(ApiEndpoints.category(id));

  Future<Paginated<ProductRecord>> stock({String? search, String? level, int page = 1}) => _read(
        'inventory/stock',
        {'search': search, 'level': level, 'page': page, 'per_page': 30},
        (body) => Paginated.fromJson(body, ProductRecord.fromJson),
        (snapshot) => snapshot.stock(search: search, level: level, page: page),
      );

  Future<StockSummary> stockSummary() => _read(
        'inventory/stock/summary',
        const {},
        (body) => StockSummary.fromJson(ApiClient.data(body)),
        (snapshot) => snapshot.stockSummary(),
      );

  Future<StockSummary?> getCachedStockSummary() async {
    final snapshot = await _snapshot?.call();
    final localSummary = snapshot?.stockSummary();
    if (localSummary != null) {
      return localSummary;
    }
    final copy = await _api.offlineCopy('inventory/stock/summary');
    if (copy == null) {
      return null;
    }
    try {
      return StockSummary.fromJson(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<Paginated<StockMovement>> movements({int? productId, String? type, String? search, int page = 1}) async {
    final body = await _api.get(
      'inventory/movements',
      query: {'product_id': productId, 'type': type, 'search': search, 'page': page, 'per_page': 30},
    );

    return Paginated.fromJson(body, StockMovement.fromJson);
  }

  Future<StockMovement> adjust({
    required int productId,
    required String type,
    required double quantity,
    int? unitCost,
    String? note,
    int? unitId,
    String? batchNumber,
    DateTime? expiresAt,
    int? batchId,
    List<String>? serials,
  }) async {
    final body = await _api.post(
      'inventory/adjustments',
      data: {
        'product_id': productId,
        'type': type,
        'quantity': quantity,
        'unit_cost': unitCost,
        'note': note,
        'unit_id': ?unitId,
        'batch_number': ?batchNumber,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String().substring(0, 10),
        'batch_id': ?batchId,
        'serials': ?serials,
      },
    );

    return StockMovement.fromJson(ApiClient.data(body));
  }

  /// Opname per batch: hasil hitung fisik tiap batch (id batch => jumlah satuan dasar).
  Future<StockMovement> batchOpname({required int productId, required Map<String, double> counts, String? note}) async =>
      StockMovement.fromJson(ApiClient.data(await _api.post('inventory/batch-opname', data: {'product_id': productId, 'counts': counts, 'note': ?note})));

  /// Batch bersaldo produk di outlet aktif, urut kedaluwarsa paling awal.
  Future<List<ProductBatchRecord>> batches(int productId) async =>
      ApiClient.list(await _api.get(ApiEndpoints.productBatches(productId), offlineCopy: false)).map(ProductBatchRecord.fromJson).toList();
}
