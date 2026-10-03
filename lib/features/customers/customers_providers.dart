import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/cached_notifier.dart';
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

final customerProvider = AsyncNotifierProvider.autoDispose.family<CustomerNotifier, Customer, int>(CustomerNotifier.new);

class CustomerNotifier extends CachedFamilyNotifier<Customer, int> {
  CustomerNotifier(super.arg);

  @override
  Future<Customer?> loadCache(int id) => ref.read(customersRepositoryProvider).getCached(id);

  @override
  Future<Customer> fetchRemote(int id) => ref.read(customersRepositoryProvider).show(id);
}

/// The customer's sales over the last year, newest first (with SWR caching).
final customerSalesProvider = AsyncNotifierProvider.autoDispose.family<CustomerSalesNotifier, SalesPage, int>(CustomerSalesNotifier.new);

class CustomerSalesNotifier extends CachedFamilyNotifier<SalesPage, int> {
  CustomerSalesNotifier(super.arg);

  DateTimeRange get _range {
    final today = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(start: today.subtract(const Duration(days: 365)), end: today);
  }

  @override
  Future<SalesPage?> loadCache(int id) {
    final range = _range;
    return ref.read(salesRepositoryProvider).getCachedList(from: range.start, to: range.end, customerId: id);
  }

  @override
  Future<SalesPage> fetchRemote(int id) {
    final range = _range;
    return ref.read(salesRepositoryProvider).list(from: range.start, to: range.end, customerId: id);
  }
}
