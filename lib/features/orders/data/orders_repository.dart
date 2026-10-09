import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'order_models.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) => OrdersRepository(ref.watch(apiClientProvider)));

class OrdersRepository {
  OrdersRepository(this._api);

  final ApiClient _api;

  Future<Paginated<CustomerOrder>> list({String? search, String status = 'open', String? type, int page = 1}) async => Paginated.fromJson(
        await _api.get(ApiEndpoints.orders, query: {'search': search, 'status': status, 'type': type, 'page': page, 'per_page': 30}, offlineCopy: false),
        CustomerOrder.fromJson,
      );

  Future<CustomerOrder> show(int id) async => CustomerOrder.fromJson(ApiClient.data(await _api.get(ApiEndpoints.order(id), offlineCopy: false)));

  Future<CustomerOrder> create(Map<String, dynamic> data) async => CustomerOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.orders, data: data)));

  Future<CustomerOrder> pay(int id, {required int amount, required String method, String? reference}) async =>
      CustomerOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.orderPayments(id), data: {'amount': amount, 'method': method, 'reference': reference})));

  Future<CustomerOrder> setStatus(int id, String status) async => CustomerOrder.fromJson(ApiClient.data(await _api.put(ApiEndpoints.orderStatus(id), data: {'status': status})));

  Future<CustomerOrder> cancel(int id, {required String reason, required bool refund}) async =>
      CustomerOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.orderCancel(id), data: {'reason': reason, 'refund': refund})));

  Future<OrderCart> cart(int id) async => OrderCart.fromJson(ApiClient.data(await _api.get(ApiEndpoints.orderCart(id), offlineCopy: false)));
}
