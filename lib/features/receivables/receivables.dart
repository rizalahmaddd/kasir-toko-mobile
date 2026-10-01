import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
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

/// Outstanding credit of one customer.
final customerReceivablesProvider = FutureProvider.autoDispose.family<List<SaleSummary>, int>((ref, customerId) async {
  final page = await ref.watch(receivablesRepositoryProvider).list(customerId: customerId);

  return page.items;
});
