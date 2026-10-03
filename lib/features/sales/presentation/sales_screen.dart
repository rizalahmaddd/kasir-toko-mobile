import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

const _statuses = [(null, 'Semua Status'), ('completed', 'Selesai'), ('credit', 'Kasbon'), ('voided', 'Dibatalkan')];

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
        title: const Text('Riwayat Transaksi'),
        hint: 'No. transaksi, pelanggan, atau barang',
        initialSearch: filter.search,
        onSearchChanged: (value) => _apply(_filter.copyWith(search: value)),
        onSearchClosed: () => _apply(_filter.copyWith(search: '')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DateFilterPill(
                    selectedRange: filter.range,
                    onRangeChanged: (range) => _apply(_filter.copyWith(range: range)),
                  ),
                  const SizedBox(width: 8),
                  FilterDropdownPill<String>(
                    label: 'Status',
                    icon: LucideIcons.badgeCheck,
                    value: filter.status,
                    items: _statuses,
                    onChanged: (val) => _apply(val == null ? filter.copyWith(clearStatus: true) : filter.copyWith(status: val)),
                  ),
                  if (filter.status != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => _apply(filter.copyWith(clearStatus: true)),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.x, size: 13),
                            SizedBox(width: 4),
                            Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
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
                          icon: LucideIcons.receiptText,
                          title: 'Belum ada transaksi',
                          description: 'Tidak ada transaksi di rentang tanggal dan filter ini.',
                        ),
                      )
                    else
                      SliverList.separated(
                        itemCount: state.page.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) => SaleTile(sale: state.page.items[index]),
                      ),
                    if (state.loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/offline'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(LucideIcons.cloudUpload, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${queued.length} transaksi offline (${rupiah(total)}) belum terkirim, jadi belum masuk daftar ini.',
                    style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 16, color: color),
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                  Text('Total Penjualan', style: theme.textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    rupiah(page.total),
                    style: AppTypography.money(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                  ),
                ],
              ),
            ),
            Container(
              height: 36,
              width: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${page.count} transaksi',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                if (page.voided > 0)
                  Text(
                    '${page.voided} dibatalkan',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
