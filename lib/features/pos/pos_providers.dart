import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/pos_models.dart';
import 'data/pos_repository.dart';

final posConfigProvider = FutureProvider<PosConfig>((ref) => ref.watch(posRepositoryProvider).config());

final posCategoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(posRepositoryProvider).categories());

class CatalogQuery {
  const CatalogQuery({this.search = '', this.categoryId});

  final String search;
  final int? categoryId;

  @override
  bool operator ==(Object other) => other is CatalogQuery && other.search == search && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(search, categoryId);
}

final catalogQueryProvider = NotifierProvider<CatalogQueryNotifier, CatalogQuery>(CatalogQueryNotifier.new);

class CatalogQueryNotifier extends Notifier<CatalogQuery> {
  @override
  CatalogQuery build() => const CatalogQuery();

  void search(String term) => state = CatalogQuery(search: term.trim(), categoryId: state.categoryId);

  void category(int? id) => state = CatalogQuery(search: state.search, categoryId: id);
}

class CatalogPage {
  const CatalogPage({required this.products, required this.page, required this.hasMore, this.loadingMore = false});

  final List<Product> products;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  CatalogPage copyWith({List<Product>? products, int? page, bool? hasMore, bool? loadingMore}) => CatalogPage(
        products: products ?? this.products,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

final catalogProvider = AsyncNotifierProvider<CatalogController, CatalogPage>(CatalogController.new);

class CatalogController extends AsyncNotifier<CatalogPage> {
  @override
  Future<CatalogPage> build() async {
    final query = ref.watch(catalogQueryProvider);
    final result = await ref.read(posRepositoryProvider).products(search: query.search, categoryId: query.categoryId);

    return CatalogPage(products: result.items, page: result.currentPage, hasMore: result.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    final query = ref.read(catalogQueryProvider);

    try {
      final result = await ref.read(posRepositoryProvider).products(search: query.search, categoryId: query.categoryId, page: current.page + 1);
      state = AsyncData(
        current.copyWith(products: [...current.products, ...result.items], page: result.currentPage, hasMore: result.hasMore, loadingMore: false),
      );
    } on Object {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}
