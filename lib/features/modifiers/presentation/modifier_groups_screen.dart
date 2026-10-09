import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/modifier_groups_repository.dart';
import '../modifiers_providers.dart';

class ModifierGroupsScreen extends ConsumerWidget {
  const ModifierGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(currentUserProvider)?.canManageMasterData ?? false;

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(ModifierStrings.screenTitle),
        hint: ModifierStrings.searchHint,
        initialSearch: ref.watch(modifierGroupsSearchProvider),
        onSearchChanged: ref.read(modifierGroupsSearchProvider.notifier).set,
      ),
      floatingActionButton: canManage
          ? AppFloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.modifierGroupNew),
              icon: const Icon(AppIcons.plus),
              label: const Text(ModifierStrings.newGroup),
            )
          : null,
      body: PagedListView<ModifierGroupRecord>(
        value: ref.watch(modifierGroupsProvider),
        onLoadMore: () => ref.read(modifierGroupsProvider.notifier).loadMore(),
        onRefresh: () => ref.refresh(modifierGroupsProvider.future),
        padding: const EdgeInsets.only(bottom: AppSpacing.s96),
        empty: const EmptyState(icon: AppIcons.listPlus, title: ModifierStrings.empty, description: ModifierStrings.emptyHint),
        itemBuilder: (context, group) => ListTile(
          onTap: canManage ? () => context.push(AppRoutes.modifierGroupDetail(group.id)) : null,
          leading: const Icon(AppIcons.listPlus),
          title: Text(group.name),
          subtitle: Text(
            [group.rule, group.options.map((o) => o.price > 0 ? '${o.name} +${rupiah(o.price)}' : o.name).join(', ')].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: group.isActive ? Text(ModifierStrings.productsCount(group.productsCount)) : const StatusBadge(label: ModifierStrings.inactive),
        ),
      ),
    );
  }
}
