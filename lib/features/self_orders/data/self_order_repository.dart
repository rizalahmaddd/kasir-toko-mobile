import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../pos/pos_providers.dart';
import 'self_order_models.dart';

final selfOrderRepositoryProvider = Provider<SelfOrderRepository>((ref) => SelfOrderRepository(ref.watch(apiClientProvider)));

/// Kotak masuk pesanan QR outlet aktif; kosong bila fiturnya tidak menyala supaya tidak memanggil server sia-sia.
final selfOrdersProvider = FutureProvider.autoDispose<List<SelfOrder>>((ref) async {
  final enabled = ref.watch(posConfigProvider.select((config) => config.value?.selfOrderEnabled ?? false));

  return enabled ? ref.read(selfOrderRepositoryProvider).list() : const [];
});

class SelfOrderRepository {
  SelfOrderRepository(this._api);

  final ApiClient _api;

  Future<List<SelfOrder>> list() async => ApiClient.list(await _api.get(ApiEndpoints.posSelfOrders, offlineCopy: false)).map(SelfOrder.fromJson).toList();

  Future<SelfOrder> accept(int id) async => SelfOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.posSelfOrderAccept(id))));

  /// Keranjang berbentuk sama dengan transaksi tertunda; barisnya membawa harga yang dikunci saat dipesan.
  Future<Map<String, dynamic>> cart(int id) async => ApiClient.data(await _api.get(ApiEndpoints.posSelfOrderCart(id), offlineCopy: false));

  /// Mengembalikan nomor transaksi yang terbentuk. Aman diulang.
  Future<String> verifyPayment(int id) async => ApiClient.data(await _api.post(ApiEndpoints.posSelfOrderVerify(id)))['number'] as String? ?? '';

  Future<SelfOrder> rejectPayment(int id) async =>
      SelfOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.posSelfOrderReject(id), data: {'target': 'payment'})));

  Future<SelfOrder> cancel(int id, {String? reason}) async =>
      SelfOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.posSelfOrderReject(id), data: {'target': 'order', 'reason': ?reason})));

  Future<SelfOrder> billAtCashier(int id) async => SelfOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.posSelfOrderBill(id))));

  Future<SelfOrder> served(int id) async => SelfOrder.fromJson(ApiClient.data(await _api.post(ApiEndpoints.posSelfOrderServed(id))));
}
