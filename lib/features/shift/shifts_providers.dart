import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
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

final shiftDetailProvider = FutureProvider.autoDispose.family<Shift, int>((ref, id) => ref.watch(shiftRepositoryProvider).show(id));

final shiftSalesProvider = FutureProvider.autoDispose.family<List<SaleSummary>, int>((ref, id) => ref.watch(shiftRepositoryProvider).sales(id));
