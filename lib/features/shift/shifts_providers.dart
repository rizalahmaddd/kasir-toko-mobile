import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/cached_notifier.dart';
import '../../core/paging/paged.dart';
import '../sales/data/sale_models.dart';
import 'data/shift_models.dart';
import 'data/shift_repository.dart';

final shiftsStatusProvider = NotifierProvider<QueryNotifier<String?>, String?>(() => QueryNotifier(null));

final shiftsProvider = AsyncNotifierProvider<ShiftsNotifier, PagedState<Shift>>(ShiftsNotifier.new);

class ShiftsNotifier extends PagedNotifier<Shift> {
  @override
  Future<Paginated<Shift>> fetch(int page) => ref.read(shiftRepositoryProvider).list(status: ref.watch(shiftsStatusProvider), page: page);
}

final shiftDetailProvider = AsyncNotifierProvider.autoDispose.family<ShiftDetailNotifier, Shift, int>(ShiftDetailNotifier.new);

class ShiftDetailNotifier extends CachedFamilyNotifier<Shift, int> {
  ShiftDetailNotifier(super.arg);

  @override
  Future<Shift?> loadCache(int id) => ref.read(shiftRepositoryProvider).getCached(id);

  @override
  Future<Shift> fetchRemote(int id) => ref.read(shiftRepositoryProvider).show(id);
}

final shiftSalesProvider = AsyncNotifierProvider.autoDispose.family<ShiftSalesNotifier, List<SaleSummary>, int>(ShiftSalesNotifier.new);

class ShiftSalesNotifier extends CachedFamilyNotifier<List<SaleSummary>, int> {
  ShiftSalesNotifier(super.arg);

  @override
  Future<List<SaleSummary>?> loadCache(int id) => ref.read(shiftRepositoryProvider).getCachedSales(id);

  @override
  Future<List<SaleSummary>> fetchRemote(int id) => ref.read(shiftRepositoryProvider).sales(id);
}
