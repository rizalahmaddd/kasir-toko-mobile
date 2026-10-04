import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/bar_chart.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
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
          title: const Text(ReportStrings.reportTitle),
          actions: [
            IconButton(
              icon: const Icon(AppIcons.copy),
              tooltip: ReportStrings.copySummary,
              onPressed: () => _copySummary(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: ReportStrings.tabOverview),
              Tab(text: ReportStrings.tabDaily),
              Tab(text: ReportStrings.tabProducts),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s10, AppSpacing.s16, AppSpacing.s2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DateFilterPill(
                  selectedRange: range,
                  defaultPreset: DateRangePresets.month,
                  onRangeChanged: ref.read(reportRangeProvider.notifier).set,
                ),
              ),
            ),
            const Expanded(child: TabBarView(children: [_Overview(), _Daily(), _Products()])),
          ],
        ),
      ),
    );
  }

  void _copySummary(BuildContext context, WidgetRef ref) {
    final range = ref.read(reportRangeProvider);
    final summaryAsync = ref.read(salesSummaryProvider);

    summaryAsync.when(
      data: (r) {
        final revenue = r.total('revenue');
        final profit = r.total('profit');
        final marginPct = percent(r.ratio('margin'));
        final count = r.total('count');
        final average = r.total('average');
        final due = r.total('due');
        final dueCount = r.total('due_count');
        final discount = r.total('discount');
        final voided = r.total('voided');
        final voidedTotal = r.total('voided_total');
        final items = quantity(r.ratio('items'));

        final buffer = StringBuffer();
        buffer.writeln('📊 *${ReportStrings.reportTitle.toUpperCase()}*');
        buffer.writeln('📅 Periode: ${dateOnly(range.start)} - ${dateOnly(range.end)}');
        buffer.writeln('');
        buffer.writeln('💰 *${ReportStrings.financialHealth.toUpperCase()}*');
        buffer.writeln('• ${ReportStrings.omzet}: ${rupiah(revenue)}');
        buffer.writeln('• ${ReportStrings.grossProfit}: ${rupiah(profit)} ($marginPct)');
        buffer.writeln('• ${ReportStrings.transactions}: $count nota');
        buffer.writeln('• ${ReportStrings.average}/Nota: ${rupiah(average)}');
        buffer.writeln('');
        buffer.writeln('⚠️ *${ReportStrings.riskMetrics.toUpperCase()}*');
        if (due > 0) {
          buffer.writeln('• ${ReportStrings.credit}: ${rupiah(due)} ($dueCount ${ReportStrings.unpaidNote})');
        }
        if (discount > 0) {
          buffer.writeln('• ${ReportStrings.discount}: ${rupiah(discount)}');
        }
        if (voided > 0) {
          buffer.writeln('• ${ReportStrings.voided}: $voided ${ReportStrings.cancelledNote} (${rupiah(voidedTotal)})');
        }
        buffer.writeln('• ${ReportStrings.itemsSold}: $items');

        if (r.topProducts.isNotEmpty) {
          buffer.writeln('');
          buffer.writeln('🏆 *${ReportStrings.topProducts.toUpperCase()}*');
          for (var i = 0; i < min(5, r.topProducts.length); i++) {
            final p = r.topProducts[i];
            buffer.writeln('${i + 1}. ${p.name}: ${quantity(p.qty)} ${p.unit} (${rupiah(p.revenue)})');
          }
        }

        Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
        showMessage(context, ReportStrings.summaryCopied);
      },
      loading: () => showMessage(context, ReportStrings.summaryNotReady, isError: true),
      error: (err, _) => showMessage(context, errorMessage(err), isError: true),
    );
  }
}

String _growth(double? value) => value == null
    ? ReportStrings.noComparison
    : ReportStrings.growthVsLastPeriod(value >= 0 ? ReportStrings.trendUp : ReportStrings.trendDown, percent(value.abs()));

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(salesSummaryProvider);
    final colors = StatusColors.of(context);

    return AsyncView(
      value: report,
      onRetry: () => ref.invalidate(salesSummaryProvider),
      data: (r) {
        final revenue = r.total('revenue');
        final paymentsTotal = r.payments.fold<int>(0, (sum, p) => sum + p.total);
        final categoryTotal = r.byCategory.fold<int>(0, (sum, c) => sum + c.revenue);

        return RefreshIndicator(
          onRefresh: () => ref.refresh(salesSummaryProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              // 1. Financial Health Hero Card
              _FinancialHeroCard(
                revenue: revenue,
                profit: r.total('profit'),
                margin: r.ratio('margin'),
                count: r.total('count'),
                average: r.total('average'),
                itemsPerTx: r.ratio('items_per_transaction'),
                revenueGrowth: r.growth('revenue_growth'),
                countGrowth: r.growth('count_growth'),
              ),
              const SizedBox(height: AppSizes.s12),

              // 2. Store Health & Risk Grid
              _StoreHealthGrid(
                due: r.total('due'),
                dueCount: r.total('due_count'),
                discount: r.total('discount'),
                discountRate: r.ratio('discount_rate'),
                voided: r.total('voided'),
                voidedTotal: r.total('voided_total'),
                itemsSold: r.ratio('items'),
              ),
              const SizedBox(height: AppSizes.s8),

              // 3. Revenue Trend Chart
              const SectionTitle(ReportStrings.revenueTrend),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s8, AppSpacing.s16, AppSpacing.s16, AppSpacing.s8),
                  child: SimpleBarChart(points: r.chart),
                ),
              ),

              // 4. Payment Methods with Proportion Bar
              const SectionTitle(ReportStrings.paymentMethods),
              _PaymentProportionCard(payments: r.payments, total: paymentsTotal),

              // 5. Peak Hours with Highlight
              const SectionTitle(ReportStrings.busyHours),
              _PeakHoursCard(hourly: r.hourly),

              // 6. Top Products
              const SectionTitle(ReportStrings.topProducts),
              _TopProductsCard(products: r.topProducts),

              // 7. Categories
              if (r.byCategory.isNotEmpty) ...[
                const SectionTitle(ReportStrings.byCategory),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      children: [
                        for (final c in r.byCategory)
                          ShareBar(
                            label: c.name,
                            value: rupiah(c.revenue),
                            share: categoryTotal == 0 ? 0 : c.revenue / categoryTotal,
                            caption: ReportStrings.profitLabel(rupiah(c.profit)),
                            color: colors.info,
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              // 8. Cashiers
              if (r.byCashier.isNotEmpty) ...[
                const SectionTitle(ReportStrings.byCashier),
                Card(
                  child: Column(
                    children: [
                      for (final c in r.byCashier)
                        ListTile(
                          leading: const Icon(AppIcons.userRound, size: AppSizes.s20),
                          title: Text(c.name),
                          subtitle: Text(ReportStrings.transactionCount(c.count)),
                          trailing: Text(rupiah(c.revenue)),
                        ),
                    ],
                  ),
                ),
              ],

              // 9. Top Customers
              if (r.topCustomers.isNotEmpty) ...[
                const SectionTitle(ReportStrings.topCustomers),
                Card(
                  child: Column(
                    children: [
                      for (final c in r.topCustomers.take(10))
                        ListTile(
                          leading: const Icon(AppIcons.star, size: AppSizes.s20),
                          title: Text(c.name),
                          subtitle: Text(ReportStrings.transactionCount(c.count)),
                          trailing: Text(rupiah(c.revenue)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  child: Text(
                    ReportStrings.customerSegments(
                      percent(asDouble(r.segments['member_percent'])),
                      percent(asDouble(r.segments['general_percent'])),
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.s24),
            ],
          ),
        );
      },
    );
  }
}

class _FinancialHeroCard extends StatelessWidget {
  const _FinancialHeroCard({
    required this.revenue,
    required this.profit,
    required this.margin,
    required this.count,
    required this.average,
    required this.itemsPerTx,
    this.revenueGrowth,
    this.countGrowth,
  });

  final int revenue;
  final int profit;
  final double margin;
  final int count;
  final int average;
  final double itemsPerTx;
  final double? revenueGrowth;
  final double? countGrowth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ReportStrings.omzet.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: muted,
                ),
              ),
              if (revenueGrowth != null) _GrowthBadge(growth: revenueGrowth!),
            ],
          ),
          const SizedBox(height: AppSizes.s6),
          Text(
            rupiah(revenue),
            style: AppTypography.money(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.s14),
          Divider(height: 1, color: isDark ? AppColors.slate700 : AppColors.slate200),
          const SizedBox(height: AppSizes.s12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ReportStrings.grossProfit,
                      style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Text(
                      rupiah(profit),
                      style: AppTypography.money(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                      ),
                      child: Text(
                        ReportStrings.marginLabel(percent(margin)),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emerald600),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: isDark ? AppColors.slate700 : AppColors.slate200),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ReportStrings.transactions,
                      style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Text(
                      thousands(count),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Text(
                      countGrowth == null ? 'transaksi' : _growth(countGrowth),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: isDark ? AppColors.slate700 : AppColors.slate200),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ReportStrings.average,
                      style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Text(
                      rupiah(average),
                      style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Text(
                      ReportStrings.itemsPerTransaction(quantity(itemsPerTx)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrowthBadge extends StatelessWidget {
  const _GrowthBadge({required this.growth});

  final double growth;

  @override
  Widget build(BuildContext context) {
    final isUp = growth >= 0;
    final color = isUp ? AppColors.emerald600 : AppColors.rose600;
    final bg = isUp ? AppColors.emerald500.withValues(alpha: 0.12) : AppColors.rose500.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUp ? AppIcons.trendingUp : AppIcons.trendingDown, size: 12, color: color),
          const SizedBox(width: AppSizes.s4),
          Text(
            '${isUp ? '+' : ''}${percent(growth)} vs lalu',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _StoreHealthGrid extends StatelessWidget {
  const _StoreHealthGrid({
    required this.due,
    required this.dueCount,
    required this.discount,
    required this.discountRate,
    required this.voided,
    required this.voidedTotal,
    required this.itemsSold,
  });

  final int due;
  final int dueCount;
  final int discount;
  final double discountRate;
  final int voided;
  final int voidedTotal;
  final double itemsSold;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;

        return GridView.count(
          crossAxisCount: wide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.s8,
          crossAxisSpacing: AppSpacing.s8,
          childAspectRatio: wide ? 2.1 : 1.5,
          children: [
            StatTile(
              label: ReportStrings.credit,
              value: rupiah(due),
              caption: due > 0 ? ReportStrings.transactionCount(dueCount) : 'Lunas semua',
              icon: AppIcons.handCoins,
              color: due > 0 ? colors.warning : null,
            ),
            StatTile(
              label: ReportStrings.discount,
              value: rupiah(discount),
              caption: ReportStrings.discountOfRevenue(percent(discountRate)),
              icon: AppIcons.badgePercent,
            ),
            StatTile(
              label: ReportStrings.voided,
              value: '$voided nota',
              caption: voided > 0 ? rupiah(voidedTotal) : 'Nihil / aman',
              icon: AppIcons.ban,
              color: voided > 0 ? colors.danger : null,
            ),
            StatTile(
              label: ReportStrings.itemsSold,
              value: quantity(itemsSold),
              caption: 'Total unit terjual',
              icon: AppIcons.package,
            ),
          ],
        );
      },
    );
  }
}

const _paymentPalette = [
  AppColors.emerald500,
  AppColors.sky500,
  AppColors.violet500,
  AppColors.amber500,
  AppColors.teal600,
  AppColors.rose500,
  AppColors.indigo500,
];

class _PaymentProportionCard extends StatelessWidget {
  const _PaymentProportionCard({required this.payments, required this.total});

  final List<({String label, int total, int count})> payments;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: Text(ReportStrings.noPayments),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (var i = 0; i < payments.length; i++) ...[
                      Expanded(
                        flex: total == 0 ? 1 : max(1, (payments[i].total / total * 1000).round()),
                        child: Container(
                          color: _paymentPalette[i % _paymentPalette.length],
                        ),
                      ),
                      if (i < payments.length - 1)
                        Container(width: 2, color: isDark ? AppColors.slate900 : Colors.white),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            for (var i = 0; i < payments.length; i++) ...[
              _PaymentItemRow(
                payment: payments[i],
                share: total == 0 ? 0.0 : payments[i].total / total,
                color: _paymentPalette[i % _paymentPalette.length],
              ),
              if (i < payments.length - 1) const SizedBox(height: AppSizes.s8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentItemRow extends StatelessWidget {
  const _PaymentItemRow({
    required this.payment,
    required this.share,
    required this.color,
  });

  final ({String label, int total, int count}) payment;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSizes.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                ReportStrings.paymentShareCaption(payment.count, percent(share * 100)),
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        Text(
          rupiah(payment.total),
          style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PeakHoursCard extends StatelessWidget {
  const _PeakHoursCard({required this.hourly});

  final List<({String label, int value, bool peak})> hourly;

  @override
  Widget build(BuildContext context) {
    final peakHours = hourly.where((h) => h.peak).toList();
    final peakHour = peakHours.isNotEmpty
        ? peakHours.first
        : (hourly.isEmpty ? null : hourly.reduce((a, b) => a.value > b.value ? a : b));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (peakHour != null && peakHour.value > 0)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.amber500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: AppColors.amber500.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.clock, size: 16, color: AppColors.amber600),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: Text(
                        ReportStrings.peakHourAlert(peakHour.label, rupiah(peakHour.value)),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amber600),
                      ),
                    ),
                  ],
                ),
              ),
            SimpleBarChart(
              points: [for (final h in hourly) (label: h.label, value: h.value)],
              highlightPredicate: (i) =>
                  i < hourly.length && (hourly[i].peak || (peakHour != null && hourly[i].label == peakHour.label)),
              highlightColor: AppColors.amber500,
              height: 160,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.products});

  final List<ProductLine> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: Text(ReportStrings.noSales),
        ),
      );
    }

    final topRevenue = products.first.revenue == 0 ? 1 : products.first.revenue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          children: [
            for (var i = 0; i < min(10, products.length); i++) ...[
              _TopProductItemRow(
                rank: i + 1,
                product: products[i],
                share: products[i].revenue / topRevenue,
              ),
              if (i < min(10, products.length) - 1) const SizedBox(height: AppSizes.s12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopProductItemRow extends StatelessWidget {
  const _TopProductItemRow({
    required this.rank,
    required this.product,
    required this.share,
  });

  final int rank;
  final ProductLine product;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    final rankColor = switch (rank) {
      1 => AppColors.amber600,
      2 => AppColors.slate500,
      3 => AppColors.orange700,
      _ => muted,
    };
    final rankBg = switch (rank) {
      1 => isDark ? AppColors.amber900.withValues(alpha: 0.3) : AppColors.amber100,
      2 => isDark ? AppColors.slate700.withValues(alpha: 0.4) : AppColors.slate100,
      3 => isDark ? AppColors.orange900.withValues(alpha: 0.3) : AppColors.orange100,
      _ => isDark ? AppColors.slate800 : AppColors.slate50,
    };

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: rankBg,
                borderRadius: BorderRadius.circular(AppRadius.r6),
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    ReportStrings.productCaption(
                      quantity(product.qty),
                      product.unit,
                      rupiah(product.profit),
                      percent(product.margin),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.s8),
            Text(
              rupiah(product.revenue),
              style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.s6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r4),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: isDark ? AppColors.slate700 : AppColors.slate100,
            valueColor: AlwaysStoppedAnimation(
              rank == 1 ? AppColors.amber500 : theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
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
        final maxTotal = days.isEmpty ? 0 : days.map((d) => d.total).reduce(max);

        return RefreshIndicator(
          onRefresh: () => ref.refresh(dailyReportProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    children: [
                      InfoRow(ReportStrings.omzet, rupiah(asInt(r.summary['total'])), bold: true),
                      InfoRow(ReportStrings.transactions, thousands(asInt(r.summary['count']))),
                      InfoRow(ReportStrings.itemsSold, quantity(asDouble(r.summary['qty']))),
                      InfoRow(ReportStrings.discount, rupiah(asInt(r.summary['discount']))),
                      InfoRow(ReportStrings.costOfGoods, rupiah(asInt(r.summary['cogs']))),
                      InfoRow(
                        ReportStrings.grossProfit,
                        ReportStrings.revenueWithMargin(
                          rupiah(asInt(r.summary['profit'])),
                          percent(asDouble(r.summary['margin'])),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle(ReportStrings.byDay),
              if (days.isEmpty)
                const EmptyState(icon: AppIcons.calendarX, title: ReportStrings.noSalesInPeriod)
              else
                Column(
                  children: [
                    for (final d in days)
                      _DailyReportCard(
                        day: d,
                        maxTotal: maxTotal,
                        isHighest: days.length > 1 && d.total == maxTotal && maxTotal > 0,
                      ),
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
  const _DailyReportCard({
    required this.day,
    this.maxTotal = 0,
    this.isHighest = false,
  });

  final DailyLine day;
  final int maxTotal;
  final bool isHighest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isToday = DateUtils.isSameDay(day.date, DateTime.now());
    final progress = maxTotal > 0 ? (day.total / maxTotal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isHighest
              ? AppColors.amber500.withValues(alpha: 0.4)
              : (isDark ? AppColors.slate700 : AppColors.slate200),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          weekdayDate(day.date),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: AppSizes.s6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.emerald500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.r4),
                            ),
                            child: const Text(
                              ReportStrings.today,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emerald600),
                            ),
                          ),
                        ],
                        if (isHighest) ...[
                          const SizedBox(width: AppSizes.s6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.amber500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.r4),
                            ),
                            child: const Text(
                              '🌟 ${ReportStrings.highestDay}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.amber600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.s3),
                    Text(
                      ReportStrings.dailyCaption(day.count, quantity(day.qty)),
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
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    ReportStrings.profitAmount(rupiah(day.profit)),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600),
                  ),
                ],
              ),
            ],
          ),
          if (maxTotal > 0) ...[
            const SizedBox(height: AppSizes.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: isDark ? AppColors.slate700 : AppColors.slate100,
                valueColor: AlwaysStoppedAnimation(
                  isHighest ? AppColors.amber500 : theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _productSorts = {
  ReportProductSortKeys.revenue: ReportStrings.omzet,
  ReportProductSortKeys.profit: ReportStrings.sortProfit,
  ReportProductSortKeys.qty: ReportStrings.sortQuantity,
  ReportProductSortKeys.margin: ReportStrings.sortMargin,
};

class _Products extends ConsumerStatefulWidget {
  const _Products();

  @override
  ConsumerState<_Products> createState() => _ProductsState();
}

class _ProductsState extends ConsumerState<_Products> {
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(productReportQueryProvider);
    final notifier = ref.read(productReportQueryProvider.notifier);
    final report = ref.watch(productReportProvider);
    final isSearching = _showSearch || query.search.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
          child: Row(
            children: [
              FilterDropdownPill<String>(
                label: ReportStrings.sortLabel,
                icon: AppIcons.arrowUpDown,
                value: query.sort,
                items: [for (final e in _productSorts.entries) (e.key, ReportStrings.sortBy(e.value))],
                onChanged: (sort) => notifier.set((sort: sort ?? ReportProductSortKeys.revenue, search: query.search)),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: isSearching ? ReportStrings.closeSearch : ReportStrings.searchProducts,
                icon: Icon(
                  isSearching ? AppIcons.x : AppIcons.search,
                  size: AppSizes.s20,
                  color: isSearching ? Theme.of(context).colorScheme.primary : null,
                ),
                onPressed: () {
                  setState(() {
                    _showSearch = !isSearching;
                    if (!_showSearch) {
                      notifier.set((sort: query.sort, search: ''));
                    }
                  });
                },
              ),
            ],
          ),
        ),
        if (isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s0, AppSpacing.s16, AppSpacing.s8),
            child: SearchField(
              dense: true,
              autofocus: true,
              initialValue: query.search,
              hint: ReportStrings.searchProducts,
              onChanged: (term) => notifier.set((sort: query.sort, search: term)),
            ),
          ),
        const SizedBox(height: AppSizes.s2),
        Expanded(
          child: AsyncView(
            value: report,
            onRetry: () => ref.invalidate(productReportProvider),
            data: (r) {
              if (r.products.isEmpty) {
                return const EmptyState(icon: AppIcons.package, title: ReportStrings.noProductsSold);
              }
              final maxRevenue = r.products.first.revenue == 0 ? 1 : r.products.first.revenue;

              return RefreshIndicator(
                onRefresh: () => ref.refresh(productReportProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s24),
                  itemCount: r.products.length,
                  itemBuilder: (context, i) => _ProductReportCard(
                    product: r.products[i],
                    rank: i + 1,
                    maxRevenue: maxRevenue,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductReportCard extends StatelessWidget {
  const _ProductReportCard({
    required this.product,
    required this.rank,
    this.maxRevenue = 1,
  });

  final ProductLine product;
  final int rank;
  final int maxRevenue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isHighMargin = product.margin >= 35.0;
    final share = maxRevenue > 0 ? (product.revenue / maxRevenue).clamp(0.0, 1.0) : 0.0;

    final rankColor = switch (rank) {
      1 => AppColors.amber600,
      2 => AppColors.slate500,
      3 => AppColors.orange700,
      _ => muted,
    };
    final rankBg = switch (rank) {
      1 => isDark ? AppColors.amber900.withValues(alpha: 0.3) : AppColors.amber100,
      2 => isDark ? AppColors.slate700.withValues(alpha: 0.4) : AppColors.slate100,
      3 => isDark ? AppColors.orange900.withValues(alpha: 0.3) : AppColors.orange100,
      _ => isDark ? AppColors.slate800 : AppColors.slate50,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s6),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: rankBg,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
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
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        if (isHighMargin) ...[
                          const SizedBox(width: AppSizes.s6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.emerald500.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.r4),
                            ),
                            child: const Text(
                              ReportStrings.highMargin,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.emerald600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Text(
                      ReportStrings.productCategoryQuantity(product.category, quantity(product.qty), product.unit),
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.s8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rupiah(product.revenue),
                    style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    ReportStrings.profitWithMargin(rupiah(product.profit), percent(product.margin)),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 3,
              backgroundColor: isDark ? AppColors.slate700 : AppColors.slate100,
              valueColor: AlwaysStoppedAnimation(
                rank == 1 ? AppColors.amber500 : theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
