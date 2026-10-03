import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/paging/paged.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../products_providers.dart';
import 'movement_tile.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key, this.productId, this.productName});

  final int? productId;
  final String? productName;

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  String? _type;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = (productId: widget.productId, type: _type, search: _search);

    return Scaffold(
      appBar: widget.productId == null
          ? SearchableAppBar(
              title: const Text(ProductStrings.sectionStockCard),
              hint: ProductStrings.searchMovementProductHint,
              initialSearch: _search,
              onSearchChanged: (term) => setState(() => _search = term),
            )
          : AppBar(title: Text('Kartu stok · ${widget.productName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
            child: Row(
              children: [
                FilterDropdownPill<String>(
                  label: ProductStrings.filterLabelMovementType,
                  icon: AppIcons.arrowLeftRight,
                  value: _type,
                  items: [
                    (null, ProductStrings.filterAllMovementTypes),
                    for (final entry in stockMovementTypes.entries) (entry.key, entry.value),
                  ],
                  onChanged: (type) => setState(() => _type = type),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s2),
          Expanded(
            child: PagedListView(
              value: ref.watch(movementsProvider(query)),
              onLoadMore: () => ref.read(movementsProvider(query).notifier).loadMore(),
              onRefresh: () => ref.refresh(movementsProvider(query).future),
              padding: const EdgeInsets.fromLTRB(AppSpacing.s0, AppSpacing.s4, AppSpacing.s0, AppSpacing.s32),
              empty: const EmptyState(icon: AppIcons.history, title: ProductStrings.emptyMovementsTitle),
              itemBuilder: (context, movement) => MovementTile(movement: movement, showProduct: widget.productId == null),
            ),
          ),
        ],
      ),
    );
  }
}
