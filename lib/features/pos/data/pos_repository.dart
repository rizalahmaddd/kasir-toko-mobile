import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_cache.dart';
import '../../offline/catalog_snapshot.dart';
import '../../sales/data/sale_models.dart';
import 'pos_models.dart';

final posRepositoryProvider = Provider<PosRepository>(
  (ref) => PosRepository(ref.watch(apiClientProvider), ref.watch(offlineCacheProvider), () => ref.read(catalogSnapshotProvider.future)),
);

class PosRepository {
  PosRepository(this._api, this._cache, this._snapshot);

  final ApiClient _api;
  final OfflineCache _cache;
  final Future<CatalogSnapshot?> Function() _snapshot;

  /// Tries the server first; when it can't be reached, answers from the device copy if there is one.
  Future<T> _orOffline<T>(Future<T> Function() online, FutureOr<T?> Function() offline) async {
    try {
      return await online();
    } on ApiException catch (error) {
      if (!error.isNetworkError) {
        rethrow;
      }
      return await offline() ?? (throw error);
    }
  }

  Future<PosConfig> config() => _orOffline(
        () async {
          final data = ApiClient.data(await _api.get(ApiEndpoints.posConfig));
          await _cache.put('pos_config', data);
          return PosConfig.fromJson(data);
        },
        () {
          final cached = _cache.get('pos_config');
          return cached == null ? null : PosConfig.fromJson(cached as Map<String, dynamic>);
        },
      );

  Future<PosConfig> updateSettings({
    bool? allowNegativeStock,
    bool? allowCredit,
    bool? autoPrint,
  }) async {
    final payload = <String, dynamic>{};
    if (allowNegativeStock != null) payload['allow_negative_stock'] = allowNegativeStock;
    if (allowCredit != null) payload['allow_credit'] = allowCredit;
    if (autoPrint != null) payload['auto_print'] = autoPrint;

    final data = ApiClient.data(await _api.patch(ApiEndpoints.posSettings, data: payload));
    await _cache.put('pos_config', data);
    return PosConfig.fromJson(data);
  }

  Future<List<Category>> categories() => _orOffline(
        () async {
          final list = ApiClient.list(await _api.get(ApiEndpoints.posCategories));
          await _cache.put('pos_categories', list);
          return list.map(Category.fromJson).toList();
        },
        () => (_cache.get('pos_categories') as List?)?.cast<Map<String, dynamic>>().map(Category.fromJson).toList(),
      );

  Future<Paginated<Product>> products({String? search, int? categoryId, int page = 1}) => _orOffline(
        () async {
          final body = await _api.get(ApiEndpoints.posProducts, query: {'search': search, 'category_id': categoryId, 'page': page, 'per_page': 48});
          return Paginated.fromJson(body, Product.fromJson);
        },
        () async => (await _snapshot())?.search(term: search, categoryId: categoryId, page: page),
      );

  /// Fresh price & stock for a restored cart. Products missing from the result were deleted or disabled.
  Future<List<Product>> productsByIds(Iterable<int> ids) => _orOffline(
        () async => Paginated.fromJson(await _api.get(ApiEndpoints.posProducts, query: {'ids': ids.join(',')}), Product.fromJson).items,
        () async => (await _snapshot())?.byIds(ids),
      );

  Future<Product> lookup(String code) => _orOffline(
        () async => Product.fromJson(ApiClient.data(await _api.get(ApiEndpoints.posProductsLookup, query: {'code': code}))),
        () async {
          final snapshot = await _snapshot();
          if (snapshot == null) {
            return null;
          }
          return snapshot.lookup(code) ?? (throw ApiException(message: PosStrings.codeNotFound(code), statusCode: 404));
        },
      );

  Future<List<CustomerOption>> customers(String search) async =>
      ApiClient.list(await _api.get(ApiEndpoints.posCustomers, query: {'search': search})).map(CustomerOption.fromJson).toList();

  Future<CustomerOption> createCustomer({required String name, String? phone}) async =>
      CustomerOption.fromJson(ApiClient.data(await _api.post(ApiEndpoints.posCustomers, data: {'name': name, 'phone': phone})));

  Future<QrisPayment> qris(int amount) async => QrisPayment.fromJson(ApiClient.data(await _api.get(ApiEndpoints.posQris, query: {'amount': amount})));

  static Map<String, dynamic> checkoutPayload({required Cart cart, required List<PaymentLine> payments, required int expectedTotal, PosConfig? config}) => {
    'client_uuid': cart.clientUuid,
    'customer_id': cart.customer?.id,
    'items': cart.items.map((item) => item.toCheckoutJson()).toList(),
    'discount_type': cart.discountType?.name,
    'discount_value': cart.discountType == null ? null : cart.discountValue,
    'payments': payments.map((payment) => payment.toJson()).toList(),
    'note': cart.note,
    'expected_total': expectedTotal,
    'prescription_id': ?cart.prescription?.id,
    if (cart.prescription == null && cart.prescriptionDraft != null) 'prescription': cart.prescriptionDraft!.toJson(),
        'order_type': ?cart.orderTypeFor(config),
        'customer_order_id': ?cart.customerOrder?.id,
    if (cart.orderTypeFor(config) == OrderTypes.dineIn && (cart.table ?? '').isNotEmpty) 'table_label': cart.table,
    if (cart.kitchenSent.isNotEmpty) 'kitchen_sent': cart.kitchenSent,
  };

  /// Safe to repeat: the server returns the existing sale for a `client_uuid` it has already stored.
  /// A queued sale goes to the outlet it was made in, not the one selected now, and is flagged
  /// `offline` so the server accepts it even if that outlet has been locked in the meantime.
  Future<SaleDetail> submitCheckout(Map<String, dynamic> payload, {int? outletId, bool offline = false}) async {
    final body = {...payload, 'outlet_id': ?outletId, if (offline) 'offline': true};
    final response = await _api.post(ApiEndpoints.posCheckout, data: body, headers: outletId == null ? null : {outletHeader: '$outletId'});

    return SaleDetail.fromJson(ApiClient.data(response));
  }

  Future<SaleDetail> checkout({required Cart cart, required List<PaymentLine> payments, required int expectedTotal, PosConfig? config}) =>
      submitCheckout(checkoutPayload(cart: cart, payments: payments, expectedTotal: expectedTotal, config: config));

  Future<List<HeldOrder>> heldOrders() async => ApiClient.list(await _api.get(ApiEndpoints.posHeldOrders)).map(HeldOrder.fromJson).toList();

  Future<HeldOrder> holdOrder({required Cart cart, required int total, String? label, PosConfig? config}) async {
    final body = await _api.post(
      ApiEndpoints.posHeldOrders,
      data: {
        'label': label,
        'cart': {...cart.toJson(total: total), 'orderType': ?cart.orderTypeFor(config)},
      },
    );
    final ticketId = ((body as Map<String, dynamic>)['meta'] as Map<String, dynamic>?)?['kitchen_ticket_id'];

    return HeldOrder.fromJson(ApiClient.data(body)).withKitchenTicket(ticketId is num ? ticketId.toInt() : null);
  }

  Future<HeldOrder> resumeHeldOrder(int id) async => HeldOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.posHeldOrderResume(id))));

Future<void> deleteHeldOrder(int id) => _api.delete(ApiEndpoints.posHeldOrder(id));

  /// Nomor seri yang masih ada di stok outlet aktif. Offline: kosong, kasir mengetik/scan manual.
  Future<List<String>> availableSerials(int productId, {String search = ''}) async {
    try {
      final body = await _api.get(ApiEndpoints.posProductSerials(productId), query: {'search': search}, offlineCopy: false);
      return (body['data'] as List? ?? const []).map((s) => '$s').toList();
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        return const [];
      }
      rethrow;
    }
  }
}
