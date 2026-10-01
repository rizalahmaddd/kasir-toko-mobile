import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../products_providers.dart';
import 'product_widgets.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(stockQueryProvider);
    final notifier = ref.read(stockQueryProvider.notifier);
    final summary = ref.watch(stockSummaryProvider).value;
    final colors = StatusColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok barang'),
        actions: [
          IconButton(
            tooltip: 'Kartu stok',
            icon: const Icon(LucideIcons.history, size: 20),
            onPressed: () => context.push('/stock/movements'),
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
            if (summary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.1,
                  children: [
                    StatTile(label: 'Dilacak', value: thousands(summary.tracked), icon: LucideIcons.package),
                    StatTile(
                      label: 'Menipis',
                      value: thousands(summary.low),
                      icon: LucideIcons.triangleAlert,
                      color: colors.warning,
                      onTap: () => notifier.set((search: query.search, level: 'low')),
                    ),
                    StatTile(
                      label: 'Habis',
                      value: thousands(summary.out),
                      icon: LucideIcons.circleSlash,
                      color: colors.danger,
                      onTap: () => notifier.set((search: query.search, level: 'out')),
                    ),
                    StatTile(label: 'Nilai stok', value: rupiah(summary.value), icon: LucideIcons.wallet),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchField(hint: 'Cari nama, SKU, atau barcode', onChanged: (term) => notifier.set((search: term, level: query.level))),
            ),
            ChoiceChips<String>(
              options: const [(null, 'Semua'), ('low', 'Menipis'), ('out', 'Habis')],
              selected: query.level,
              onSelected: (level) => notifier.set((search: query.search, level: level)),
            ),
            const SizedBox(height: 4),
          ],
        ),
        empty: const EmptyState(icon: LucideIcons.warehouse, title: 'Tidak ada barang', description: 'Ubah kata kunci atau filter.'),
        itemBuilder: (context, product) => ProductTile(product: product, showPrice: false, onTap: () => context.push('/product/${product.id}')),
      ),
    );
  }
}
