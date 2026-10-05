import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/paging/paged.dart';
import 'data/prescription_models.dart';
import 'data/prescriptions_repository.dart';

typedef PrescriptionsQuery = ({String search, String status});

final prescriptionsQueryProvider =
    NotifierProvider<QueryNotifier<PrescriptionsQuery>, PrescriptionsQuery>(() => QueryNotifier((search: '', status: 'open')));

final prescriptionsProvider = AsyncNotifierProvider<PrescriptionsNotifier, PagedState<Prescription>>(PrescriptionsNotifier.new);

class PrescriptionsNotifier extends PagedNotifier<Prescription> {
  @override
  Future<Paginated<Prescription>> fetch(int page) {
    final query = ref.watch(prescriptionsQueryProvider);

    return ref.read(prescriptionsRepositoryProvider).list(search: query.search, status: query.status, page: page);
  }
}

final prescriptionProvider = FutureProvider.autoDispose.family<Prescription, int>((ref, id) => ref.read(prescriptionsRepositoryProvider).show(id));

final prescriptionImageProvider = FutureProvider.autoDispose.family<List<int>, int>((ref, id) => ref.read(prescriptionsRepositoryProvider).image(id));
