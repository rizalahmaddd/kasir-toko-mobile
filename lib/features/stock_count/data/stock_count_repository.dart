import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'stock_count_models.dart';

final stockCountRepositoryProvider = Provider<StockCountRepository>((ref) => StockCountRepository(ref.watch(apiClientProvider)));

class StockCountRepository {
  StockCountRepository(this._api);

  final ApiClient _api;

  Future<Paginated<StockCountDoc>> list({String status = 'open', int page = 1}) async => Paginated.fromJson(
        await _api.get(ApiEndpoints.stockCounts, query: {'status': status, 'page': page, 'per_page': 30}),
        StockCountDoc.fromJson,
      );

  Future<StockCountDoc> show(int id) async => StockCountDoc.fromJson(ApiClient.data(await _api.get(ApiEndpoints.stockCount(id))));

  Future<StockCountDoc> start({required String scope, bool? blindCount, bool? holdAdjustments, String? note}) async => StockCountDoc.fromJson(
        ApiClient.data(await _api.post(ApiEndpoints.stockCounts, data: {'scope': scope, 'blind_count': ?blindCount, 'hold_adjustments': ?holdAdjustments, 'note': ?note})),
      );

  Future<Paginated<CountItem>> items(int id, {String? filter, String? search, int page = 1}) async => Paginated.fromJson(
        await _api.get(ApiEndpoints.stockCountItems(id), query: {'filter': filter, 'search': search, 'page': page, 'per_page': 50}),
        CountItem.fromJson,
      );

  Future<CountCatalog> catalog(int id) async {
    final body = await _api.get(ApiEndpoints.stockCountCatalog(id)) as Map<String, dynamic>;

    return CountCatalog(ApiClient.list(body).map(CountCatalogItem.fromJson).toList(), scopeAll: body['scope'] == 'all');
  }

  Future<CountLookup> lookup(int id, String code) async =>
      CountLookup.fromJson(await _api.get(ApiEndpoints.stockCountLookup(id), query: {'code': code}, offlineCopy: false) as Map<String, dynamic>);

  Future<void> addItems(int id, List<int> productIds) => _api.post(ApiEndpoints.stockCountItems(id), data: {'product_ids': productIds});

  /// Hasil per entri: `{client_uuid, status: saved|duplicate|rejected, reason?, error?, entry_id?}`.
  Future<List<Map<String, dynamic>>> sendEntries(int id, List<Map<String, dynamic>> entries, DateTime now, {int? outletId}) async => ApiClient.list(
        await _api.post(
          ApiEndpoints.stockCountEntries(id),
          data: {'device_sent_at': now.toUtc().toIso8601String(), 'entries': entries},
          headers: outletId == null ? null : {outletHeader: '$outletId'},
        ),
      );

  Future<List<Map<String, dynamic>>> sendSerials(int id, List<Map<String, dynamic>> serials, DateTime now, {int? outletId}) async => ApiClient.list(
        await _api.post(
          ApiEndpoints.stockCountSerials(id),
          data: {'device_sent_at': now.toUtc().toIso8601String(), 'serials': serials},
          headers: outletId == null ? null : {outletHeader: '$outletId'},
        ),
      );

  Future<void> voidEntry(int id, int entryId) => _api.delete(ApiEndpoints.stockCountEntry(id, entryId));

  Future<void> recordUnknown(int id, {required String barcode, required double quantity, String? note}) =>
      _api.post(ApiEndpoints.stockCountUnknown(id), data: {'barcode': barcode, 'quantity': quantity, 'note': ?note});

  Future<StockCountDoc> submit(int id) async => StockCountDoc.fromJson(ApiClient.data(await _api.post(ApiEndpoints.stockCountSubmit(id))));

  Future<StockCountDoc> reopen(int id) async => StockCountDoc.fromJson(ApiClient.data(await _api.post(ApiEndpoints.stockCountReopen(id))));

  Future<CountPreview> preview(int id) async => CountPreview.fromJson(ApiClient.data(await _api.get(ApiEndpoints.stockCountPreview(id), offlineCopy: false)));

  Future<CountItem> updateItem(int id, int itemId, {String? reason, bool clearReason = false, bool? needsRecount}) async => CountItem.fromJson(
        ApiClient.data(await _api.patch(ApiEndpoints.stockCountItem(id, itemId), data: {
          if (reason != null || clearReason) 'reason': reason,
          'needs_recount': ?needsRecount,
        })),
      );

  Future<StockCountDoc> post(int id, {required String uncountedPolicy}) async =>
      StockCountDoc.fromJson(ApiClient.data(await _api.post(ApiEndpoints.stockCountPost(id), data: {'uncounted_policy': uncountedPolicy})));

  Future<StockCountDoc> cancel(int id, {String? reason}) async =>
      StockCountDoc.fromJson(ApiClient.data(await _api.post(ApiEndpoints.stockCountCancel(id), data: {'reason': ?reason})));
}
