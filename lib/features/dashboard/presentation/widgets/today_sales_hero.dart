import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json.dart';
import '../../../auth/access.dart';
import '../../../auth/auth_controller.dart';

class TodaySalesHero extends ConsumerWidget {
  const TodaySalesHero({super.key, required this.today});

  final Map<String, dynamic> today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    final revenue = asInt(today['revenue']);
    final yesterday = asInt(today['yesterday']);
    final count = asInt(today['count']);
    final profit = today['profit'] == null ? null : asInt(today['profit']);

    final diff = yesterday == 0 ? null : (revenue - yesterday) / yesterday * 100;
    final avgTicket = count > 0 ? (revenue ~/ count) : 0;
    final profitMargin = (profit != null && revenue > 0) ? (profit / revenue * 100) : null;

    final canViewReports = user?.canViewSalesReport ?? false;
    final canViewSales = user?.canViewSales ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? AppColors.slate900 : Colors.white,
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : AppColors.slate900.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            if (canViewReports) {
              context.push('/reports/sales');
            } else if (canViewSales) {
              context.go('/sales');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.chartColumnIncreasing,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Penjualan Hari Ini',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                            ),
                          ),
                          Text(
                            count > 0 ? '$count transaksi dicatat' : 'Belum ada transaksi',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canViewReports || canViewSales)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : AppColors.slate100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              canViewReports ? 'Laporan' : 'Riwayat',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.slate300 : AppColors.slate700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.arrowUpRight,
                              size: 13,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    rupiah(revenue),
                    style: AppTypography.money(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (diff != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: diff >= 0
                              ? (isDark
                                  ? AppColors.emerald500.withValues(alpha: 0.2)
                                  : AppColors.emerald500.withValues(alpha: 0.12))
                              : (isDark
                                  ? AppColors.rose500.withValues(alpha: 0.2)
                                  : AppColors.rose500.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              diff >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                              size: 13,
                              color: diff >= 0
                                  ? (isDark ? AppColors.emerald400 : AppColors.emerald700)
                                  : (isDark ? AppColors.rose500 : AppColors.rose600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: diff >= 0
                                    ? (isDark ? AppColors.emerald400 : AppColors.emerald700)
                                    : (isDark ? AppColors.rose500 : AppColors.rose600),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'vs kemarin (${rupiah(yesterday)})',
                        style: TextStyle(
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                          fontSize: 11,
                        ),
                      ),
                    ] else
                      Text(
                        yesterday > 0 ? 'Kemarin ${rupiah(yesterday)}' : 'Awal periode hari ini',
                        style: TextStyle(
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate950.withValues(alpha: 0.6) : AppColors.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.slate800 : AppColors.slate200.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricSubItem(
                          label: 'Transaksi',
                          value: '$count',
                          caption: count > 0 ? 'Selesai' : '-',
                          isDark: isDark,
                        ),
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: isDark ? AppColors.slate800 : AppColors.slate200,
                      ),
                      Expanded(
                        child: _MetricSubItem(
                          label: 'Rata-rata/Struk',
                          value: count > 0 ? rupiah(avgTicket) : '-',
                          caption: 'Nilai belanja',
                          isDark: isDark,
                        ),
                      ),
                      if (profit != null) ...[
                        Container(
                          height: 28,
                          width: 1,
                          color: isDark ? AppColors.slate800 : AppColors.slate200,
                        ),
                        Expanded(
                          child: _MetricSubItem(
                            label: 'Laba Kotor',
                            value: rupiah(profit),
                            caption: profitMargin != null ? '${profitMargin.toStringAsFixed(0)}% margin' : 'Setelah HPP',
                            isDark: isDark,
                            valueColor: isDark ? AppColors.emerald400 : AppColors.emerald700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricSubItem extends StatelessWidget {
  const _MetricSubItem({
    required this.label,
    required this.value,
    required this.caption,
    required this.isDark,
    this.valueColor,
  });

  final String label;
  final String value;
  final String caption;
  final bool isDark;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? (isDark ? Colors.white : AppColors.slate900),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}
