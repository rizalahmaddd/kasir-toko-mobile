import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/cached_notifier.dart';
import '../../core/paging/paged.dart';
import '../sales/data/sale_models.dart';

final receivablesRepositoryProvider = Provider<ReceivablesRepository>((ref) => ReceivablesRepository(ref.watch(apiClientProvider)));

class ReceivablesRepository {
  ReceivablesRepository(this._api);

  final ApiClient _api;

  Future<Paginated<SaleSummary>> list({String? search, int? customerId, int page = 1}) async {
    final body = await _api.get('receivables', query: {'search': search, 'customer_id': customerId, 'page': page, 'per_page': 30});

    return Paginated.fromJson(body, SaleSummary.fromJson);
  }

  Future<List<SaleSummary>?> getCachedList({String? search, int? customerId, int page = 1}) async {
    final copy = await _api.offlineCopy('receivables', query: {'search': search, 'customer_id': customerId, 'page': page, 'per_page': 30});
    if (copy == null) {
      return null;
    }
    try {
      return Paginated.fromJson(copy, SaleSummary.fromJson).items;
    } catch (_) {
      return null;
    }
  }

  Future<SaleDetail> pay(int saleId, {required int amount, required String method, String? reference}) async {
    final body = await _api.post('receivables/$saleId/payments', data: {'amount': amount, 'method': method, 'reference': reference});

    return SaleDetail.fromJson(ApiClient.data(body));
  }
}

final receivablesSearchProvider = NotifierProvider<QueryNotifier<String>, String>(() => QueryNotifier(''));

final receivablesProvider = AsyncNotifierProvider<ReceivablesNotifier, PagedState<SaleSummary>>(ReceivablesNotifier.new);

class ReceivablesNotifier extends PagedNotifier<SaleSummary> {
  @override
  Future<Paginated<SaleSummary>> fetch(int page) =>
      ref.read(receivablesRepositoryProvider).list(search: ref.watch(receivablesSearchProvider), page: page);
}

/// Outstanding credit of one customer (with SWR caching).
final customerReceivablesProvider =
    AsyncNotifierProvider.autoDispose.family<CustomerReceivablesNotifier, List<SaleSummary>, int>(CustomerReceivablesNotifier.new);

class CustomerReceivablesNotifier extends CachedFamilyNotifier<List<SaleSummary>, int> {
  CustomerReceivablesNotifier(super.arg);

  @override
  Future<List<SaleSummary>?> loadCache(int id) => ref.read(receivablesRepositoryProvider).getCachedList(customerId: id);

  @override
  Future<List<SaleSummary>> fetchRemote(int id) async {
    final page = await ref.read(receivablesRepositoryProvider).list(customerId: id);
    return page.items;
  }
}
