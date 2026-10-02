import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/bar_chart.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/period_picker.dart';
import '../../../core/widgets/state_views.dart';
import '../reports.dart';

class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan penjualan'),
          bottom: const TabBar(tabs: [Tab(text: 'Ikhtisar'), Tab(text: 'Harian'), Tab(text: 'Produk')]),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            PeriodPicker(range: range, onChanged: ref.read(reportRangeProvider.notifier).set),
            const Expanded(child: TabBarView(children: [_Overview(), _Daily(), _Products()])),
          ],
        ),
      ),
    );
  }
}

String _growth(double? value) => value == null ? 'belum ada pembanding' : '${value >= 0 ? '▲' : '▼'} ${percent(value.abs())} vs periode lalu';

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(salesSummaryProvider);
    final colors = StatusColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return AsyncView(
      value: report,
      onRetry: () => ref.invalidate(salesSummaryProvider),
      data: (r) {
        final revenue = r.total('revenue');
        final paymentsTotal = r.payments.fold<int>(0, (sum, p) => sum + p.total);
        final topRevenue = r.topProducts.isEmpty ? 1 : r.topProducts.first.revenue;
        final categoryTotal = r.byCategory.fold<int>(0, (sum, c) => sum + c.revenue);

        final tiles = [
          StatTile(label: 'Omzet', value: rupiah(revenue), caption: _growth(r.growth('revenue_growth')), icon: LucideIcons.trendingUp),
          StatTile(
            label: 'Laba kotor',
            value: rupiah(r.total('profit')),
            caption: 'Margin ${percent(r.ratio('margin'))}',
            icon: LucideIcons.piggyBank,
            color: colors.success,
          ),
          StatTile(label: 'Transaksi', value: thousands(r.total('count')), caption: _growth(r.growth('count_growth')), icon: LucideIcons.receiptText),
          StatTile(label: 'Rata-rata', value: rupiah(r.total('average')), caption: '${quantity(r.ratio('items_per_transaction'))} barang/transaksi', icon: LucideIcons.calculator),
          StatTile(label: 'Kasbon', value: rupiah(r.total('due')), caption: '${r.total('due_count')} transaksi', icon: LucideIcons.handCoins, color: colors.warning),
          StatTile(label: 'Diskon', value: rupiah(r.total('discount')), caption: '${percent(r.ratio('discount_rate'))} dari omzet', icon: LucideIcons.badgePercent),
          StatTile(label: 'Dibatalkan', value: thousands(r.total('voided')), caption: rupiah(r.total('voided_total')), icon: LucideIcons.ban, color: colors.danger),
          StatTile(label: 'Barang terjual', value: quantity(r.ratio('items')), icon: LucideIcons.package),
        ];

        return RefreshIndicator(
          onRefresh: () => ref.refresh(salesSummaryProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: wide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: wide ? 2.0 : 1.45,
                children: tiles,
              ),
              const SectionTitle('Tren omzet'),
              Card(child: Padding(padding: const EdgeInsets.fromLTRB(8, 16, 16, 8), child: SimpleBarChart(points: r.chart))),
              const SectionTitle('Metode pembayaran'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: r.payments.isEmpty
                      ? const Text('Belum ada pembayaran.')
                      : Column(
                          children: [
                            for (final p in r.payments)
                              ShareBar(
                                label: p.label,
                                value: rupiah(p.total),
                                share: paymentsTotal == 0 ? 0 : p.total / paymentsTotal,
                                caption: '${p.count} transaksi · ${percent(paymentsTotal == 0 ? 0 : p.total / paymentsTotal * 100)}',
                              ),
                          ],
                        ),
                ),
              ),
              const SectionTitle('Produk terlaris'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: r.topProducts.isEmpty
                      ? const Text('Belum ada penjualan.')
                      : Column(
                          children: [
                            for (final p in r.topProducts.take(10))
                              ShareBar(
                                label: p.name,
                                value: rupiah(p.revenue),
                                share: p.revenue / topRevenue,
                                caption: '${quantity(p.qty)} ${p.unit} · laba ${rupiah(p.profit)} (${percent(p.margin)})',
                              ),
                          ],
                        ),
                ),
              ),
              if (r.byCategory.isNotEmpty) ...[
                const SectionTitle('Per kategori'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final c in r.byCategory)
                          ShareBar(
                            label: c.name,
                            value: rupiah(c.revenue),
                            share: categoryTotal == 0 ? 0 : c.revenue / categoryTotal,
                            caption: 'Laba ${rupiah(c.profit)}',
                            color: colors.info,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SectionTitle('Jam ramai'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  child: SimpleBarChart(points: [for (final h in r.hourly) (label: h.label, value: h.value)], height: 160),
                ),
              ),
              if (r.byCashier.isNotEmpty) ...[
                const SectionTitle('Per kasir'),
                Card(
                  child: Column(
                    children: [
                      for (final c in r.byCashier)
                        ListTile(
                          leading: const Icon(LucideIcons.userRound, size: 20),
                          title: Text(c.name),
                          subtitle: Text('${c.count} transaksi'),
                          trailing: Text(rupiah(c.revenue)),
                        ),
                    ],
                  ),
                ),
              ],
              if (r.topCustomers.isNotEmpty) ...[
                const SectionTitle('Pelanggan teratas'),
                Card(
                  child: Column(
                    children: [
                      for (final c in r.topCustomers.take(10))
                        ListTile(
                          leading: const Icon(LucideIcons.star, size: 20),
                          title: Text(c.name),
                          subtitle: Text('${c.count} transaksi'),
                          trailing: Text(rupiah(c.revenue)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Pelanggan terdaftar: ${percent(asDouble(r.segments['member_percent']))} omzet · umum ${percent(asDouble(r.segments['general_percent']))}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _Daily extends ConsumerWidget {
  const _Daily();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(dailyReportProvider);

    return AsyncView(
      value: report,
      onRetry: () => ref.invalidate(dailyReportProvider),
      data: (r) {
        final days = r.days.where((d) => d.count > 0).toList().reversed.toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(dailyReportProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      InfoRow('Omzet', rupiah(asInt(r.summary['total'])), bold: true),
                      InfoRow('Transaksi', thousands(asInt(r.summary['count']))),
                      InfoRow('Barang terjual', quantity(asDouble(r.summary['qty']))),
                      InfoRow('Diskon', rupiah(asInt(r.summary['discount']))),
                      InfoRow('Modal (HPP)', rupiah(asInt(r.summary['cogs']))),
                      InfoRow('Laba kotor', '${rupiah(asInt(r.summary['profit']))} · ${percent(asDouble(r.summary['margin']))}'),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Per hari'),
              if (days.isEmpty)
                const EmptyState(icon: LucideIcons.calendarX, title: 'Tidak ada penjualan di periode ini')
              else
                Column(
                  children: [
                    for (final d in days)
                      _DailyReportCard(day: d),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyReportCard extends StatelessWidget {
  const _DailyReportCard({required this.day});

  final DailyLine day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isToday = DateUtils.isSameDay(day.date, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                Row(
                  children: [
                    Text(
                      dateOnly(day.date),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Hari ini',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.count} transaksi · ${quantity(day.qty)} barang',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupiah(day.total),
                style: AppTypography.money(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'laba ${rupiah(day.profit)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _productSorts = {'revenue': 'Omzet', 'profit': 'Laba', 'qty': 'Jumlah', 'margin': 'Margin'};

class _Products extends ConsumerWidget {
  const _Products();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productReportQueryProvider);
    final notifier = ref.read(productReportQueryProvider.notifier);
    final report = ref.watch(productReportProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchField(hint: 'Cari produk', onChanged: (term) => notifier.set((sort: query.sort, search: term))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              FilterDropdownPill<String>(
                label: 'Urutan',
                icon: LucideIcons.arrowUpDown,
                value: query.sort,
                items: [for (final e in _productSorts.entries) (e.key, 'Urut ${e.value}')],
                onChanged: (sort) => notifier.set((sort: sort ?? 'revenue', search: query.search)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: AsyncView(
            value: report,
            onRetry: () => ref.invalidate(productReportProvider),
            data: (r) => r.products.isEmpty
                ? const EmptyState(icon: LucideIcons.package, title: 'Tidak ada produk terjual')
                : RefreshIndicator(
                    onRefresh: () => ref.refresh(productReportProvider.future),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: r.products.length,
                      itemBuilder: (context, i) => _ProductReportCard(
                        product: r.products[i],
                        rank: i + 1,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ProductReportCard extends StatelessWidget {
  const _ProductReportCard({required this.product, required this.rank});

  final ProductLine product;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    final rankColor = switch (rank) {
      1 => const Color(0xFFD97706),
      2 => const Color(0xFF64748B),
      3 => const Color(0xFFC2410C),
      _ => muted,
    };
    final rankBg = switch (rank) {
      1 => isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
      2 => isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
      3 => isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
      _ => isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.category} · ${quantity(product.qty)} ${product.unit}',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupiah(product.revenue),
                style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'laba ${rupiah(product.profit)} (${percent(product.margin)})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
