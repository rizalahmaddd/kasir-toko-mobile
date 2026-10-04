import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../../offline/offline_queue.dart';
import '../data/sale_models.dart';
import 'sale_tile.dart';
import '../sales_controller.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

const _statuses = [(null, SalesStrings.allStatuses), (SaleStatuses.completed, SalesStrings.statusCompleted), (SaleStatuses.credit, SalesStrings.statusCredit), (SaleStatuses.voided, SalesStrings.statusVoided)];

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(salesProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  SalesFilter get _filter => ref.read(salesFilterProvider);

  void _apply(SalesFilter filter) => ref.read(salesFilterProvider.notifier).update(filter);

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(salesFilterProvider);
    final sales = ref.watch(salesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(SalesStrings.salesHistoryTitle),
        hint: SalesStrings.salesSearchHint,
        initialSearch: filter.search,
        onSearchChanged: (value) => _apply(_filter.copyWith(search: value)),
        onSearchClosed: () => _apply(_filter.copyWith(search: '')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s8, AppSpacing.s12, AppSpacing.s8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DateFilterPill(
                    selectedRange: filter.range,
                    onRangeChanged: (range) => _apply(_filter.copyWith(range: range)),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  FilterDropdownPill<String>(
                    label: SalesStrings.statusFilterLabel,
                    icon: AppIcons.badgeCheck,
                    value: filter.status,
                    items: _statuses,
                    onChanged: (val) => _apply(val == null ? filter.copyWith(clearStatus: true) : filter.copyWith(status: val)),
                  ),
                  if (filter.status != null) ...[
                    const SizedBox(width: AppSizes.s6),
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.r9),
                      onTap: () => _apply(filter.copyWith(clearStatus: true)),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : AppColors.slate100,
                          borderRadius: BorderRadius.circular(AppRadius.r9),
                          border: Border.all(
                            color: isDark ? AppColors.slate700 : AppColors.slate300,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.x, size: AppSizes.s13),
                            SizedBox(width: AppSizes.s4),
                            Text(SalesStrings.reset, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
            child: AsyncView(
              value: sales,
              onRetry: () => ref.invalidate(salesProvider),
              loading: const SalesListSkeleton(),
              data: (state) => RefreshIndicator(
                onRefresh: () => ref.refresh(salesProvider.future),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _Summary(page: state.page)),
                    const SliverToBoxAdapter(child: _QueuedNotice()),
                    if (state.page.items.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: AppIcons.receiptText,
                          title: SalesStrings.emptySalesTitle,
                          description: SalesStrings.emptySalesDescription,
                        ),
                      )
                    else
                      SliverList.separated(
                        itemCount: state.page.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.s2),
                        itemBuilder: (context, index) => SaleTile(sale: state.page.items[index]),
                      ),
                    if (state.loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                          child: AppShimmer(
                            child: SkeletonBox(height: 72, borderRadius: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sales recorded offline only reach this list once the server has them.
class _QueuedNotice extends ConsumerWidget {
  const _QueuedNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = ref.watch(myQueueProvider);
    if (queued.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = StatusColors.of(context).warning;
    final total = queued.fold<int>(0, (sum, sale) => sum + sale.total);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s0, AppSpacing.s16, AppSpacing.s8),
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: () => context.push(AppRoutes.offline),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
            child: Row(
              children: [
                Icon(AppIcons.cloudUpload, size: AppSizes.s18, color: color),
                const SizedBox(width: AppSizes.s10),
                Expanded(
                  child: Text(
                    SalesStrings.offlineQueuedNotice(queued.length, rupiah(total)),
                    style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(AppIcons.chevronRight, size: AppSizes.s16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.page});

  final SalesPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s6, AppSpacing.s16, AppSpacing.s8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(SalesStrings.totalSales, style: theme.textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    rupiah(page.total),
                    style: AppTypography.money(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.emerald600),
                  ),
                ],
              ),
            ),
            Container(
              height: 36,
              width: 1,
              color: isDark ? AppColors.slate700 : AppColors.slate200,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  SalesStrings.transactionCount(page.count),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                if (page.voided > 0)
                  Text(
                    SalesStrings.voidedCount(page.voided),
                    style: const TextStyle(fontSize: 11, color: AppColors.red600, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
