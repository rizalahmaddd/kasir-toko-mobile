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

  Future<SaleDetail?> getCached(int id) async {
    final copy = await _api.offlineCopy('sales/$id');
    if (copy == null) {
      return null;
    }
    try {
      return SaleDetail.fromJson(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<SalesPage?> getCachedList({
    required DateTime from,
    required DateTime to,
    String? status,
    String? search,
    String? method,
    int? customerId,
    int page = 1,
  }) async {
    final copy = await _api.offlineCopy(
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
    if (copy == null) {
      return null;
    }
    try {
      final paged = Paginated.fromJson(copy, SaleSummary.fromJson);
      final summary = paged.meta['summary'] as Map<String, dynamic>? ?? const {};

      return SalesPage(
        items: paged.items,
        hasMore: paged.hasMore,
        page: paged.currentPage,
        count: (summary['count'] as num?)?.toInt() ?? 0,
        total: (summary['total'] as num?)?.toInt() ?? 0,
        voided: (summary['voided'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Receipt> receipt(int id) async => Receipt.fromJson(ApiClient.data(await _api.get('sales/$id/receipt')));

  Future<Receipt?> getCachedReceipt(int id) async {
    final copy = await _api.offlineCopy('sales/$id/receipt');
    if (copy == null) {
      return null;
    }
    try {
      return Receipt.fromJson(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<SaleDetail> voidSale(int id, String reason) async {
    final body = await _api.post('sales/$id/void', data: {'reason': reason});
    await _api.updateCached('sales/$id', body);
    return SaleDetail.fromJson(ApiClient.data(body));
  }
}
