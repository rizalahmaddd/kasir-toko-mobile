import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/paging/paged.dart';
import '../sales/data/sale_models.dart';
import '../sales/data/sales_repository.dart';
import 'data/customers_repository.dart';

typedef CustomersQuery = ({String search, bool? isActive});

final customersQueryProvider = NotifierProvider<QueryNotifier<CustomersQuery>, CustomersQuery>(() => QueryNotifier((search: '', isActive: null)));

final customersProvider = AsyncNotifierProvider<CustomersNotifier, PagedState<Customer>>(CustomersNotifier.new);

class CustomersNotifier extends PagedNotifier<Customer> {
  @override
  Future<Paginated<Customer>> fetch(int page) {
    final query = ref.watch(customersQueryProvider);

    return ref.read(customersRepositoryProvider).list(search: query.search, isActive: query.isActive, page: page);
  }
}

final customerProvider = FutureProvider.autoDispose.family<Customer, int>((ref, id) => ref.watch(customersRepositoryProvider).show(id));

/// The customer's sales over the last year, newest first.
final customerSalesProvider = FutureProvider.autoDispose.family<SalesPage, int>((ref, id) {
  final today = DateUtils.dateOnly(DateTime.now());

  return ref.watch(salesRepositoryProvider).list(from: today.subtract(const Duration(days: 365)), to: today, customerId: id);
});
