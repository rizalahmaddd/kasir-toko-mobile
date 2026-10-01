import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/paging/paged.dart';
import 'data/product_models.dart';
import 'data/products_repository.dart';

typedef ProductsQuery = ({String search, int? categoryId, String? status, String sort});

final productsQueryProvider = NotifierProvider<QueryNotifier<ProductsQuery>, ProductsQuery>(
  () => QueryNotifier((search: '', categoryId: null, status: null, sort: 'name')),
);

final productsProvider = AsyncNotifierProvider<ProductsNotifier, PagedState<ProductRecord>>(ProductsNotifier.new);

class ProductsNotifier extends PagedNotifier<ProductRecord> {
  @override
  Future<Paginated<ProductRecord>> fetch(int page) {
    final query = ref.watch(productsQueryProvider);

    return ref.read(productsRepositoryProvider).products(
          search: query.search,
          categoryId: query.categoryId,
          status: query.status,
          sort: query.sort,
          page: page,
        );
  }
}

final productDetailProvider = FutureProvider.autoDispose.family<ProductRecord, int>((ref, id) => ref.watch(productsRepositoryProvider).product(id));

/// Every category, for pickers and filter chips.
final allCategoriesProvider = FutureProvider<List<CategoryRecord>>((ref) async {
  final page = await ref.watch(productsRepositoryProvider).categories(perPage: 100);

  return page.items;
});

final categoriesSearchProvider = NotifierProvider<QueryNotifier<String>, String>(() => QueryNotifier(''));

final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, PagedState<CategoryRecord>>(CategoriesNotifier.new);

class CategoriesNotifier extends PagedNotifier<CategoryRecord> {
  @override
  Future<Paginated<CategoryRecord>> fetch(int page) =>
      ref.read(productsRepositoryProvider).categories(search: ref.watch(categoriesSearchProvider), page: page);
}

typedef StockQuery = ({String search, String? level});

final stockQueryProvider = NotifierProvider<QueryNotifier<StockQuery>, StockQuery>(() => QueryNotifier((search: '', level: null)));

final stockProvider = AsyncNotifierProvider<StockNotifier, PagedState<ProductRecord>>(StockNotifier.new);

class StockNotifier extends PagedNotifier<ProductRecord> {
  @override
  Future<Paginated<ProductRecord>> fetch(int page) {
    final query = ref.watch(stockQueryProvider);

    return ref.read(productsRepositoryProvider).stock(search: query.search, level: query.level, page: page);
  }
}

final stockSummaryProvider = FutureProvider.autoDispose<StockSummary>((ref) => ref.watch(productsRepositoryProvider).stockSummary());

typedef MovementsQuery = ({int? productId, String? type, String search});

final movementsProvider = AsyncNotifierProvider.autoDispose.family<MovementsNotifier, PagedState<StockMovement>, MovementsQuery>(
  MovementsNotifier.new,
);

class MovementsNotifier extends PagedNotifier<StockMovement> {
  MovementsNotifier(this.query);

  final MovementsQuery query;

  @override
  Future<Paginated<StockMovement>> fetch(int page) =>
      ref.read(productsRepositoryProvider).movements(productId: query.productId, type: query.type, search: query.search, page: page);
}

const stockMovementTypes = {
  'sale': 'Penjualan',
  'sale_void': 'Batal jual',
  'stock_in': 'Stok masuk',
  'stock_out': 'Stok keluar',
  'opname': 'Opname',
  'initial': 'Stok awal',
};
