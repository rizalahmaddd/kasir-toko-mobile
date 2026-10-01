import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import 'sale_models.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) => SalesRepository(ref.watch(apiClientProvider)));

final _apiDate = DateFormat('yyyy-MM-dd');

class SalesRepository {
  SalesRepository(this._api);

  final ApiClient _api;

  Future<SalesPage> list({
    required DateTime from,
    required DateTime to,
    String? status,
    String? search,
    String? method,
    int? customerId,
    int page = 1,
  }) async {
    final body = await _api.get(
      'sales',
      query: {
        'from': _apiDate.format(from),
        'to': _apiDate.format(to),
        'status': status,
        'search': search,
        'method': method,
        'customer_id': customerId,
        'page': page,
        'per_page': 30,
      },
    );
    final paged = Paginated.fromJson(body, SaleSummary.fromJson);
    final summary = paged.meta['summary'] as Map<String, dynamic>? ?? const {};

    return SalesPage(
      items: paged.items,
      hasMore: paged.hasMore,
      page: paged.currentPage,
      count: (summary['count'] as num?)?.toInt() ?? 0,
      total: (summary['total'] as num?)?.toInt() ?? 0,
      voided: (summary['voided'] as num?)?.toInt() ?? 0,
    );
  }

  Future<SaleDetail> show(int id) async => SaleDetail.fromJson(ApiClient.data(await _api.get('sales/$id')));

  Future<Receipt> receipt(int id) async => Receipt.fromJson(ApiClient.data(await _api.get('sales/$id/receipt')));

  Future<SaleDetail> voidSale(int id, String reason) async =>
      SaleDetail.fromJson(ApiClient.data(await _api.post('sales/$id/void', data: {'reason': reason})));
}
