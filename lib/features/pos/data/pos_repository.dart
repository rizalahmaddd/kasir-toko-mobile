import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../sales/data/sale_models.dart';
import 'pos_models.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepository(ref.watch(apiClientProvider)));

class PosRepository {
  PosRepository(this._api);

  final ApiClient _api;

  Future<PosConfig> config() async => PosConfig.fromJson(ApiClient.data(await _api.get('pos/config')));

  Future<List<Category>> categories() async => ApiClient.list(await _api.get('pos/categories')).map(Category.fromJson).toList();

  Future<Paginated<Product>> products({String? search, int? categoryId, int page = 1}) async {
    final body = await _api.get('pos/products', query: {'search': search, 'category_id': categoryId, 'page': page, 'per_page': 48});

    return Paginated.fromJson(body, Product.fromJson);
  }

  /// Fresh price & stock for a restored cart. Products missing from the result were deleted or disabled.
  Future<List<Product>> productsByIds(Iterable<int> ids) async {
    final body = await _api.get('pos/products', query: {'ids': ids.join(',')});

    return Paginated.fromJson(body, Product.fromJson).items;
  }

  Future<Product> lookup(String code) async => Product.fromJson(ApiClient.data(await _api.get('pos/products/lookup', query: {'code': code})));

  Future<List<CustomerOption>> customers(String search) async =>
      ApiClient.list(await _api.get('pos/customers', query: {'search': search})).map(CustomerOption.fromJson).toList();

  Future<CustomerOption> createCustomer({required String name, String? phone}) async =>
      CustomerOption.fromJson(ApiClient.data(await _api.post('pos/customers', data: {'name': name, 'phone': phone})));

  Future<QrisPayment> qris(int amount) async => QrisPayment.fromJson(ApiClient.data(await _api.get('pos/qris', query: {'amount': amount})));

  Future<SaleDetail> checkout({required Cart cart, required List<PaymentLine> payments, required int expectedTotal}) async {
    final body = await _api.post(
      'pos/checkout',
      data: {
        'client_uuid': cart.clientUuid,
        'customer_id': cart.customer?.id,
        'items': cart.items.map((item) => item.toCheckoutJson()).toList(),
        'discount_type': cart.discountType?.name,
        'discount_value': cart.discountType == null ? null : cart.discountValue,
        'payments': payments.map((payment) => payment.toJson()).toList(),
        'note': cart.note,
        'expected_total': expectedTotal,
      },
    );

    return SaleDetail.fromJson(ApiClient.data(body));
  }

  Future<List<HeldOrder>> heldOrders() async => ApiClient.list(await _api.get('pos/held-orders')).map(HeldOrder.fromJson).toList();

  Future<void> holdOrder({required Cart cart, required int total, String? label}) =>
      _api.post('pos/held-orders', data: {'label': label, 'cart': cart.toJson(total: total)});

  Future<HeldOrder> resumeHeldOrder(int id) async => HeldOrder.fromJson(ApiClient.data(await _api.post('pos/held-orders/$id/resume')));

  Future<void> deleteHeldOrder(int id) => _api.delete('pos/held-orders/$id');
}
