import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/paging/paged.dart';
import 'data/order_models.dart';
import 'data/orders_repository.dart';

typedef OrdersQuery = ({String search, String status});

final ordersQueryProvider = NotifierProvider<QueryNotifier<OrdersQuery>, OrdersQuery>(() => QueryNotifier((search: '', status: 'open')));

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, PagedState<CustomerOrder>>(OrdersNotifier.new);

class OrdersNotifier extends PagedNotifier<CustomerOrder> {
  @override
  Future<Paginated<CustomerOrder>> fetch(int page) {
    final query = ref.watch(ordersQueryProvider);

    return ref.read(ordersRepositoryProvider).list(search: query.search, status: query.status, page: page);
  }
}

final orderProvider = FutureProvider.autoDispose.family<CustomerOrder, int>((ref, id) => ref.read(ordersRepositoryProvider).show(id));
