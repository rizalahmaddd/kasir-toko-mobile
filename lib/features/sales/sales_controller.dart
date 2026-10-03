import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/cached_notifier.dart';
import 'data/sale_models.dart';
import 'data/sales_repository.dart';

class SalesFilter {
  const SalesFilter({required this.range, this.status, this.search = ''});

  factory SalesFilter.today() {
    final now = DateUtils.dateOnly(DateTime.now());
    return SalesFilter(range: DateTimeRange(start: now, end: now));
  }

  final DateTimeRange range;
  final String? status;
  final String search;

  SalesFilter copyWith({DateTimeRange? range, String? status, bool clearStatus = false, String? search}) => SalesFilter(
        range: range ?? this.range,
        status: clearStatus ? null : status ?? this.status,
        search: search ?? this.search,
      );

  @override
  bool operator ==(Object other) => other is SalesFilter && other.range == range && other.status == status && other.search == search;

  @override
  int get hashCode => Object.hash(range, status, search);
}

final salesFilterProvider = NotifierProvider<SalesFilterNotifier, SalesFilter>(SalesFilterNotifier.new);

class SalesFilterNotifier extends Notifier<SalesFilter> {
  @override
  SalesFilter build() => SalesFilter.today();

  void update(SalesFilter filter) => state = filter;
}

class SalesState {
  const SalesState({required this.page, this.loadingMore = false});

  final SalesPage page;
  final bool loadingMore;
}

final salesProvider = AsyncNotifierProvider<SalesController, SalesState>(SalesController.new);

class SalesController extends AsyncNotifier<SalesState> {
  @override
  Future<SalesState> build() async => SalesState(page: await _fetch(ref.watch(salesFilterProvider), 1));

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.page.hasMore || current.loadingMore) {
      return;
    }

    state = AsyncData(SalesState(page: current.page, loadingMore: true));

    try {
      final next = await _fetch(ref.read(salesFilterProvider), current.page.page + 1);
      state = AsyncData(
        SalesState(
          page: SalesPage(
            items: [...current.page.items, ...next.items],
            hasMore: next.hasMore,
            page: next.page,
            count: next.count,
            total: next.total,
            voided: next.voided,
          ),
        ),
      );
    } on Object {
      state = AsyncData(SalesState(page: current.page));
    }
  }

  Future<SalesPage> _fetch(SalesFilter filter, int page) => fetchSales(ref.read(salesRepositoryProvider), filter, page);
}

/// Shared with the offline warm-up, which must ask for exactly what this list asks for.
Future<SalesPage> fetchSales(SalesRepository repository, SalesFilter filter, int page) => repository.list(
      from: filter.range.start,
      to: filter.range.end,
      status: filter.status,
      search: filter.search,
      page: page,
    );

final saleDetailProvider = AsyncNotifierProvider.autoDispose.family<SaleDetailNotifier, SaleDetail, int>(SaleDetailNotifier.new);

class SaleDetailNotifier extends CachedFamilyNotifier<SaleDetail, int> {
  SaleDetailNotifier(super.arg);

  @override
  Future<SaleDetail?> loadCache(int id) => ref.read(salesRepositoryProvider).getCached(id);

  @override
  Future<SaleDetail> fetchRemote(int id) => ref.read(salesRepositoryProvider).show(id);
}
