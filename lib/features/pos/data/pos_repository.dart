import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          final data = ApiClient.data(await _api.get('pos/config'));
          await _cache.put('pos_config', data);
          return PosConfig.fromJson(data);
        },
        () {
          final cached = _cache.get('pos_config');
          return cached == null ? null : PosConfig.fromJson(cached as Map<String, dynamic>);
        },
      );

  Future<List<Category>> categories() => _orOffline(
        () async {
          final list = ApiClient.list(await _api.get('pos/categories'));
          await _cache.put('pos_categories', list);
          return list.map(Category.fromJson).toList();
        },
        () => (_cache.get('pos_categories') as List?)?.cast<Map<String, dynamic>>().map(Category.fromJson).toList(),
      );

  Future<Paginated<Product>> products({String? search, int? categoryId, int page = 1}) => _orOffline(
        () async {
          final body = await _api.get('pos/products', query: {'search': search, 'category_id': categoryId, 'page': page, 'per_page': 48});
          return Paginated.fromJson(body, Product.fromJson);
        },
        () async => (await _snapshot())?.search(term: search, categoryId: categoryId, page: page),
      );

  /// Fresh price & stock for a restored cart. Products missing from the result were deleted or disabled.
  Future<List<Product>> productsByIds(Iterable<int> ids) => _orOffline(
        () async => Paginated.fromJson(await _api.get('pos/products', query: {'ids': ids.join(',')}), Product.fromJson).items,
        () async => (await _snapshot())?.byIds(ids),
      );

  Future<Product> lookup(String code) => _orOffline(
        () async => Product.fromJson(ApiClient.data(await _api.get('pos/products/lookup', query: {'code': code}))),
        () async {
          final snapshot = await _snapshot();
          if (snapshot == null) {
            return null;
          }
          return snapshot.lookup(code) ?? (throw ApiException(message: 'Kode $code tidak ditemukan.', statusCode: 404));
        },
      );

  Future<List<CustomerOption>> customers(String search) async =>
      ApiClient.list(await _api.get('pos/customers', query: {'search': search})).map(CustomerOption.fromJson).toList();

  Future<CustomerOption> createCustomer({required String name, String? phone}) async =>
      CustomerOption.fromJson(ApiClient.data(await _api.post('pos/customers', data: {'name': name, 'phone': phone})));

  Future<QrisPayment> qris(int amount) async => QrisPayment.fromJson(ApiClient.data(await _api.get('pos/qris', query: {'amount': amount})));

  static Map<String, dynamic> checkoutPayload({required Cart cart, required List<PaymentLine> payments, required int expectedTotal}) => {
        'client_uuid': cart.clientUuid,
        'customer_id': cart.customer?.id,
        'items': cart.items.map((item) => item.toCheckoutJson()).toList(),
        'discount_type': cart.discountType?.name,
        'discount_value': cart.discountType == null ? null : cart.discountValue,
        'payments': payments.map((payment) => payment.toJson()).toList(),
        'note': cart.note,
        'expected_total': expectedTotal,
      };

  /// Safe to repeat: the server returns the existing sale for a `client_uuid` it has already stored.
  Future<SaleDetail> submitCheckout(Map<String, dynamic> payload) async => SaleDetail.fromJson(ApiClient.data(await _api.post('pos/checkout', data: payload)));

  Future<SaleDetail> checkout({required Cart cart, required List<PaymentLine> payments, required int expectedTotal}) =>
      submitCheckout(checkoutPayload(cart: cart, payments: payments, expectedTotal: expectedTotal));

  Future<List<HeldOrder>> heldOrders() async => ApiClient.list(await _api.get('pos/held-orders')).map(HeldOrder.fromJson).toList();

  Future<HeldOrder> holdOrder({required Cart cart, required int total, String? label}) async =>
      HeldOrder.fromJson(ApiClient.data(await _api.post('pos/held-orders', data: {'label': label, 'cart': cart.toJson(total: total)})));

  Future<HeldOrder> resumeHeldOrder(int id) async => HeldOrder.fromJson(ApiClient.data(await _api.post('pos/held-orders/$id/resume')));

  Future<void> deleteHeldOrder(int id) => _api.delete('pos/held-orders/$id');
}
