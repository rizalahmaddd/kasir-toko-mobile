import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'kitchen_models.dart';

final kitchenRepositoryProvider = Provider<KitchenRepository>((ref) => KitchenRepository(ref.watch(apiClientProvider)));

final kitchenStatusProvider = NotifierProvider<QueryNotifierKitchen, String>(QueryNotifierKitchen.new);

class QueryNotifierKitchen extends Notifier<String> {
  @override
  String build() => 'pending';

  void set(String value) => state = value;
}

final kitchenTicketsProvider = FutureProvider.autoDispose<List<KitchenTicket>>((ref) => ref.read(kitchenRepositoryProvider).list(status: ref.watch(kitchenStatusProvider)));

class KitchenRepository {
  KitchenRepository(this._api);

  final ApiClient _api;

  static const _path = 'pos/kitchen-tickets';

  Future<List<KitchenTicket>> list({String status = 'pending'}) async =>
      ApiClient.list(await _api.get(_path, query: {'status': status}, offlineCopy: false)).map(KitchenTicket.fromJson).toList();

  Future<KitchenTicket> show(int id) async => KitchenTicket.fromJson(ApiClient.data(await _api.get('$_path/$id', offlineCopy: false)));

  Future<KitchenTicket> done(int id) async => KitchenTicket.fromJson(ApiClient.data(await _api.post('$_path/$id/done')));

  Future<KitchenTicket> reopen(int id) async => KitchenTicket.fromJson(ApiClient.data(await _api.post('$_path/$id/reopen')));
}
