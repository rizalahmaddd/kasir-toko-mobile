import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/api_endpoints.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/offline_cache.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/json.dart';
import '../pos/data/pos_models.dart';
import '../products/data/product_models.dart';

/// Every sellable product as of [updatedAt], so the cashier can keep selling without the server.
class CatalogSnapshot {
  CatalogSnapshot(this.products, this.updatedAt);

  final List<Map<String, dynamic>> products;
  final DateTime updatedAt;

  static const pageSize = 48;

  Paginated<Product> search({String? term, int? categoryId, int page = 1}) {
    final needle = (term ?? '').trim().toLowerCase();
    final matches = products.map(Product.fromJson).where((product) {
      if (categoryId != null && product.categoryId != categoryId) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return product.name.toLowerCase().contains(needle) ||
          (product.sku ?? '').toLowerCase().contains(needle) ||
          (product.barcode ?? '').toLowerCase() == needle;
    }).toList();
    final lastPage = matches.isEmpty ? 1 : (matches.length / pageSize).ceil();
    final start = (page - 1) * pageSize;

    return Paginated(
      items: start >= matches.length ? const [] : matches.sublist(start, (start + pageSize).clamp(0, matches.length)),
      currentPage: page,
      lastPage: lastPage,
    );
  }

  Product? lookup(String code) {
    final match = products.where((p) => p['barcode'] == code).firstOrNull ?? products.where((p) => p['sku'] == code).firstOrNull;
    return match == null ? null : Product.fromJson(match);
  }

  List<Product> byIds(Iterable<int> ids) {
    final wanted = ids.toSet();
    return products.where((p) => wanted.contains(p['id'])).map(Product.fromJson).toList();
  }

  /// Product screens answered from the snapshot while offline. It only holds active products,
  /// so asking for inactive ones returns null and the caller falls back to its own copy.
  Paginated<ProductRecord>? records({String? search, int? categoryId, String? status, String? sort, int page = 1}) {
    if (status == ProductStatuses.inactive) {
      return null;
    }
    final sortKey = (sort ?? ProductSortKeys.name).replaceFirst('-', '');
    int compare(ProductRecord a, ProductRecord b) => switch (sortKey) {
          ProductSortKeys.price => a.price.compareTo(b.price),
          ProductSortKeys.stock => a.stock.compareTo(b.stock),
          ProductSortKeys.sku => a.sku.compareTo(b.sku),
          _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        };
    final matches = _records(search).where((p) => (categoryId == null || p.category?.id == categoryId) && (status != StockLevels.low || p.isLowStock)).toList()
      ..sort((a, b) => (sort ?? '').startsWith('-') ? compare(b, a) : compare(a, b));

    return _page(matches, page, 30);
  }

  Paginated<ProductRecord> stock({String? search, String? level, int page = 1}) {
    final matches = _records(search).where((p) {
      if (!p.trackStock) {
        return false;
      }
      return switch (level) {
        StockLevels.low => p.isLowStock && p.stock > 0,
        StockLevels.out => p.stock <= 0,
        _ => true,
      };
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return _page(matches, page, 30);
  }

  StockSummary stockSummary() {
    final tracked = _records(null).where((p) => p.trackStock).toList();
    return StockSummary(
      tracked: tracked.length,
      low: tracked.where((p) => p.isLowStock && p.stock > 0).length,
      out: tracked.where((p) => p.stock <= 0).length,
      value: tracked.where((p) => p.stock > 0).fold(0, (sum, p) => sum + (p.stock * p.costPrice).round()),
    );
  }

  /// Categories that still have an active product; the snapshot doesn't know about empty ones.
  List<CategoryRecord> categories() {
    final byId = <int, CategoryRecord>{};
    for (final product in products) {
      final category = product['category'];
      if (category is Map<String, dynamic>) {
        byId[category['id'] as int] = CategoryRecord.fromJson(category);
      }
    }
    return byId.values.toList()..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.name.compareTo(b.name));
  }

  ProductRecord? record(int id) {
    final match = products.where((p) => p['id'] == id).firstOrNull;
    return match == null ? null : _record(match);
  }

  // is_low_stock is recomputed because offline sales lower the stock after the snapshot was taken.
  ProductRecord _record(Map<String, dynamic> json) => ProductRecord.fromJson({
        ...json,
        'is_low_stock': json['track_stock'] == true && asDouble(json['stock']) <= asDouble(json['min_stock']),
      });

  Iterable<ProductRecord> _records(String? term) {
    final needle = (term ?? '').trim().toLowerCase();
    return products.map(_record).where(
          (p) =>
              needle.isEmpty ||
              p.name.toLowerCase().contains(needle) ||
              p.sku.toLowerCase().contains(needle) ||
              (p.barcode ?? '').toLowerCase().contains(needle),
        );
  }

  static Paginated<T> _page<T>(List<T> matches, int page, int size) {
    final start = (page - 1) * size;
    return Paginated(
      items: start >= matches.length ? const [] : matches.sublist(start, (start + size).clamp(0, matches.length)),
      currentPage: page,
      lastPage: matches.isEmpty ? 1 : (matches.length / size).ceil(),
    );
  }

  /// Deducts stock for a sale recorded offline so the catalog doesn't offer what's already gone.
  CatalogSnapshot deduct(Map<int, double> quantities) => CatalogSnapshot(
        [
          for (final p in products)
            quantities.containsKey(p['id']) && p['track_stock'] == true ? {...p, 'stock': asDouble(p['stock']) - quantities[p['id']]!} : p,
        ],
        updatedAt,
      );
}

final catalogSnapshotProvider = AsyncNotifierProvider<CatalogSnapshotNotifier, CatalogSnapshot?>(CatalogSnapshotNotifier.new);

class CatalogSnapshotNotifier extends AsyncNotifier<CatalogSnapshot?> {
  OfflineCache get _cache => ref.read(offlineCacheProvider);

  @override
  Future<CatalogSnapshot?> build() async {
    final stored = asMap(await ref.watch(offlineCacheProvider).readFile(StorageKeys.catalog));
    if (stored.isEmpty) {
      return null;
    }

    return CatalogSnapshot(asList(stored['products']), DateTime.parse(stored['updated_at'] as String));
  }

  /// Downloads the whole active catalog, 100 products per request.
  Future<CatalogSnapshot> download() async {
    final api = ref.read(apiClientProvider);
    final products = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;

    do {
      final body = await api.get(ApiEndpoints.posProducts, query: {'page': page, 'per_page': 100});
      products.addAll(ApiClient.list(body));
      lastPage = asInt(asMap((body as Map<String, dynamic>)['meta'])['last_page']);
      page++;
    } while (page <= lastPage);

    final snapshot = CatalogSnapshot(products, DateTime.now());
    await _save(snapshot);
    state = AsyncData(snapshot);

    return snapshot;
  }

  /// The new stock is visible as soon as this returns its future, before the file is written,
  /// so screens reloaded right after a sale already read it.
  Future<void> deduct(Map<int, double> quantities) async {
    final current = state.value ?? await future;
    if (current == null) {
      return;
    }
    final updated = current.deduct(quantities);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> _save(CatalogSnapshot snapshot) =>
      _cache.writeFile(StorageKeys.catalog, {'products': snapshot.products, 'updated_at': snapshot.updatedAt.toIso8601String()});
}
