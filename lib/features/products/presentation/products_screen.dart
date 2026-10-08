import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/paging/paged.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../pos/presentation/widgets/barcode_scanner_dialog.dart';
import '../products_providers.dart';
import 'product_widgets.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';

final _sorts = {
  ProductSortKeys.name: ProductStrings.sortOptions[0],
  ProductSortKeys.nameDesc: ProductStrings.sortOptions[1],
  ProductSortKeys.price: ProductStrings.sortOptions[2],
  ProductSortKeys.priceDesc: ProductStrings.sortOptions[3],
  ProductSortKeys.stock: ProductStrings.sortOptions[4],
  ProductSortKeys.stockDesc: ProductStrings.sortOptions[5],
  ProductSortKeys.sku: ProductStrings.sortOptions[6],
};

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productsQueryProvider);
    final notifier = ref.read(productsQueryProvider.notifier);
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final canManage = ref.watch(currentUserProvider)?.canManageMasterData ?? false;

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(ProductStrings.appTitleProducts),
        hint: ProductStrings.searchProductHint,
        initialSearch: query.search,
        onSearchChanged: (term) => notifier.set((search: term, categoryId: query.categoryId, status: query.status, sort: query.sort)),
        actions: [
          PopupMenuButton<String>(
            tooltip: ProductStrings.tooltipSort,
            icon: const Icon(AppIcons.arrowUpDown, size: AppSizes.s20),
            initialValue: query.sort,
            onSelected: (sort) => notifier.set((search: query.search, categoryId: query.categoryId, status: query.status, sort: sort)),
            itemBuilder: (_) => [for (final entry in _sorts.entries) PopupMenuItem(value: entry.key, child: Text(entry.value))],
          ),
          IconButton(
            tooltip: ProductStrings.tooltipSearchByBarcode,
            icon: const Icon(AppIcons.scanBarcode, size: AppSizes.s20),
            onPressed: () async {
              final code = await BarcodeScannerDialog.open(context);
              if (code != null) {
                notifier.set((search: code, categoryId: null, status: null, sort: query.sort));
              }
            },
          ),
        ],
      ),
      floatingActionButton: canManage
          ? AppFloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.productNew),
              icon: const Icon(AppIcons.plus),
              label: const Text(ProductStrings.appTitleProducts),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterDropdownPill<String>(
                    label: ProductStrings.filterLabelStatus,
                    icon: AppIcons.badgeCheck,
                    value: query.status,
                    items: const [
                      (null, ProductStrings.filterAllStatus),
                      (ProductStatuses.active, ProductStrings.statusActive),
                      (ProductStatuses.inactive, ProductStrings.statusInactive),
                      (StockLevels.low, ProductStrings.filterStatusLowStock),
                    ],
                    onChanged: (status) => notifier.set((search: query.search, categoryId: query.categoryId, status: status, sort: query.sort)),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(width: AppSizes.s8),
                    FilterDropdownPill<int>(
                      label: ProductStrings.filterLabelCategory,
                      icon: AppIcons.tag,
                      value: query.categoryId,
                      items: [
                        (null, ProductStrings.filterAllCategories),
                        for (final category in categories) (category.id, category.name),
                      ],
                      onChanged: (id) => notifier.set((search: query.search, categoryId: id, status: query.status, sort: query.sort)),
                    ),
                  ],
                  if (query.status != null || query.categoryId != null) ...[
                    const SizedBox(width: AppSizes.s6),
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.r9),
                      onTap: () => notifier.set((search: query.search, categoryId: null, status: null, sort: query.sort)),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.slate800 : AppColors.slate100,
                          borderRadius: BorderRadius.circular(AppRadius.r9),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.slate700 : AppColors.slate300,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.x, size: AppSizes.s13),
                            SizedBox(width: AppSizes.s4),
                            Text(ProductStrings.actionReset, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s2),
          Expanded(
            child: PagedListView(
              value: ref.watch(productsProvider),
              skeleton: const ProductListSkeleton(),
              onLoadMore: () => ref.read(productsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(productsProvider.future),
              padding: const EdgeInsets.only(bottom: AppSpacing.s96),
              empty: const EmptyState(icon: AppIcons.package, title: ProductStrings.emptyProductsTitle, description: ProductStrings.emptyFilterHint),
              itemBuilder: (context, product) => ProductTile(product: product, onTap: () => context.push(AppRoutes.productDetail(product.id))),
            ),
          ),
        ],
      ),
    );
  }
}
