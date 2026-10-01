import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/bar_chart.dart';
import '../../../core/widgets/common.dart';
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
                childAspectRatio: wide ? 2.0 : 1.55,
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

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
                Card(
                  child: Column(
                    children: [
                      for (final (i, d) in days.indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          title: Text(DateUtils.isSameDay(d.date, DateTime.now()) ? 'Hari ini' : dateOnly(d.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${d.count} transaksi · ${quantity(d.qty)} barang · laba ${rupiah(d.profit)}', style: TextStyle(color: muted)),
                          trailing: Text(rupiah(d.total)),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchField(hint: 'Cari produk', onChanged: (term) => notifier.set((sort: query.sort, search: term))),
        ),
        ChoiceChips<String>(
          options: [for (final e in _productSorts.entries) (e.key, 'Urut ${e.value.toLowerCase()}')],
          selected: query.sort,
          onSelected: (sort) => notifier.set((sort: sort ?? 'revenue', search: query.search)),
        ),
        Expanded(
          child: AsyncView(
            value: report,
            onRetry: () => ref.invalidate(productReportProvider),
            data: (r) => r.products.isEmpty
                ? const EmptyState(icon: LucideIcons.package, title: 'Tidak ada produk terjual')
                : RefreshIndicator(
                    onRefresh: () => ref.refresh(productReportProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24, top: 4),
                      itemCount: r.products.length,
                      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                      itemBuilder: (context, i) {
                        final p = r.products[i];
                        return ListTile(
                          leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.category} · ${quantity(p.qty)} ${p.unit} · margin ${percent(p.margin)}', style: TextStyle(color: muted)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(rupiah(p.revenue)),
                              Text('laba ${rupiah(p.profit)}', style: TextStyle(fontSize: 12, color: StatusColors.of(context).success)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
