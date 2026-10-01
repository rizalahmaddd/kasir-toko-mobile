import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/offline_cache.dart';
import '../../core/utils/json.dart';
import '../pos/data/pos_models.dart';

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
    final stored = asMap(await ref.watch(offlineCacheProvider).readFile('catalog'));
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
      final body = await api.get('pos/products', query: {'page': page, 'per_page': 100});
      products.addAll(ApiClient.list(body));
      lastPage = asInt(asMap((body as Map<String, dynamic>)['meta'])['last_page']);
      page++;
    } while (page <= lastPage);

    final snapshot = CatalogSnapshot(products, DateTime.now());
    await _save(snapshot);
    state = AsyncData(snapshot);

    return snapshot;
  }

  Future<void> deduct(Map<int, double> quantities) async {
    final current = await future;
    if (current == null) {
      return;
    }
    final updated = current.deduct(quantities);
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> _save(CatalogSnapshot snapshot) =>
      _cache.writeFile('catalog', {'products': snapshot.products, 'updated_at': snapshot.updatedAt.toIso8601String()});
}
