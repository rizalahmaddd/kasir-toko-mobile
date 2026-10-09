import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/paging/paged.dart';
import 'data/modifier_groups_repository.dart';

final modifierGroupsSearchProvider = NotifierProvider<QueryNotifier<String>, String>(() => QueryNotifier(''));

final modifierGroupsProvider = AsyncNotifierProvider<ModifierGroupsNotifier, PagedState<ModifierGroupRecord>>(ModifierGroupsNotifier.new);

class ModifierGroupsNotifier extends PagedNotifier<ModifierGroupRecord> {
  @override
  Future<Paginated<ModifierGroupRecord>> fetch(int page) =>
      ref.read(modifierGroupsRepositoryProvider).list(search: ref.watch(modifierGroupsSearchProvider), page: page);
}

final modifierGroupProvider = FutureProvider.autoDispose.family<ModifierGroupRecord, int>((ref, id) => ref.read(modifierGroupsRepositoryProvider).show(id));
