import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../stock_count/data/stock_count_models.dart';
import '../../stock_count/stock_count_providers.dart';
import '../products_providers.dart';
import 'product_widgets.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(stockQueryProvider);
    final notifier = ref.read(stockQueryProvider.notifier);
    final summary = ref.watch(stockSummaryProvider).value;
    final colors = StatusColors.of(context);
    final canCount = ref.watch(currentUserProvider)?.canCountStock ?? false;
    final openCounts = canCount ? ref.watch(openStockCountsProvider).value ?? const [] : const <StockCountDoc>[];
    final counting = canCount ? ref.watch(countingProductsProvider).value ?? const <int?, String>{} : const <int?, String>{};

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(ProductStrings.appTitleStock),
        hint: ProductStrings.searchProductHint,
        initialSearch: query.search,
        onSearchChanged: (term) => notifier.set((search: term, level: query.level)),
        actions: [
          IconButton(
            tooltip: ProductStrings.sectionStockCard,
            icon: const Icon(AppIcons.history, size: AppSizes.s20),
            onPressed: () => context.push(AppRoutes.stockMovements),
          ),
        ],
      ),
      body: PagedListView(
        value: ref.watch(stockProvider),
        onLoadMore: () => ref.read(stockProvider.notifier).loadMore(),
        onRefresh: () {
          ref.invalidate(stockSummaryProvider);
          return ref.refresh(stockProvider.future);
        },
        header: Column(
          children: [
            for (final count in openCounts)
              Container(
                margin: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s4),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.clipboardCheck, size: AppSizes.s20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSizes.s10),
                    Expanded(
                      child: Text(
                        StockCountStrings.openBanner(count.number),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                      ),
                      onPressed: () => context.push(AppRoutes.stockCountDetail(count.id)),
                      child: const Text(StockCountStrings.openAction, style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            if (summary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s8),
                child: GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: MediaQuery.sizeOf(context).width >= 600 ? 2.0 : 1.65,
                  children: [
                    StatTile(label: ProductStrings.statTracked, value: thousands(summary.tracked), icon: AppIcons.package),
                    StatTile(
                      label: ProductStrings.statusLowStock,
                      value: thousands(summary.low),
                      icon: AppIcons.triangleAlert,
                      color: colors.warning,
                      onTap: () => notifier.set((search: query.search, level: StockLevels.low)),
                    ),
                    StatTile(
                      label: ProductStrings.statusOutOfStock,
                      value: thousands(summary.out),
                      icon: AppIcons.circleSlash,
                      color: colors.danger,
                      onTap: () => notifier.set((search: query.search, level: StockLevels.out)),
                    ),
                    StatTile(label: ProductStrings.statStockValue, value: rupiah(summary.value), icon: AppIcons.wallet),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s0, AppSpacing.s16, AppSpacing.s8),
              child: Row(
                children: [
                  FilterDropdownPill<String>(
                    label: ProductStrings.filterLabelStockStatus,
                    icon: AppIcons.packageCheck,
                    value: query.level,
                    items: const [
                      (null, ProductStrings.filterAllStock),
                      (StockLevels.low, ProductStrings.filterStatusLowStock),
                      (StockLevels.out, ProductStrings.filterStatusOutOfStock),
                    ],
                    onChanged: (level) => notifier.set((search: query.search, level: level)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.s2),
          ],
        ),
        empty: const EmptyState(icon: AppIcons.warehouse, title: ProductStrings.emptyStockTitle, description: ProductStrings.emptyFilterHint),
        itemBuilder: (context, product) => ProductTile(
          product: product,
          showPrice: false,
          countingNumber: counting[product.id] ?? counting[null],
          onTap: () => context.push(AppRoutes.productDetail(product.id)),
        ),
      ),
    );
  }
}
