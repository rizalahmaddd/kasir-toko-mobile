import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json.dart';
import '../../../auth/access.dart';
import '../../../auth/auth_controller.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

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
        borderRadius: BorderRadius.circular(AppRadius.r18),
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
        borderRadius: BorderRadius.circular(AppRadius.r18),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r18),
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            if (canViewReports) {
              context.push(AppRoutes.reportsSales);
            } else if (canViewSales) {
              context.go(AppRoutes.sales);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r10),
                      ),
                      child: Icon(
                        AppIcons.chartColumnIncreasing,
                        size: AppSizes.s16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSizes.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DashboardStrings.todaySalesTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                            ),
                          ),
                          Text(
                            count > 0 ? DashboardStrings.todayTransactionCount(count) : DashboardStrings.todayNoTransactions,
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
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : AppColors.slate100,
                          borderRadius: BorderRadius.circular(AppRadius.r20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              canViewReports ? DashboardStrings.reportLinkLabel : DashboardStrings.historyLinkLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.slate300 : AppColors.slate700,
                              ),
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Icon(
                              AppIcons.arrowUpRight,
                              size: AppSizes.s13,
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.s14),
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
                const SizedBox(height: AppSizes.s8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (diff != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                        decoration: BoxDecoration(
                          color: diff >= 0
                              ? (isDark
                                  ? AppColors.emerald500.withValues(alpha: 0.2)
                                  : AppColors.emerald500.withValues(alpha: 0.12))
                              : (isDark
                                  ? AppColors.rose500.withValues(alpha: 0.2)
                                  : AppColors.rose500.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(AppRadius.r6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              diff >= 0 ? AppIcons.trendingUp : AppIcons.trendingDown,
                              size: AppSizes.s13,
                              color: diff >= 0
                                  ? (isDark ? AppColors.emerald400 : AppColors.emerald700)
                                  : (isDark ? AppColors.rose500 : AppColors.rose600),
                            ),
                            const SizedBox(width: AppSizes.s4),
                            Text(
                              DashboardStrings.percentChange(diff),
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
                        DashboardStrings.vsYesterday(rupiah(yesterday)),
                        style: TextStyle(
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                          fontSize: 11,
                        ),
                      ),
                    ] else
                      Text(
                        yesterday > 0 ? DashboardStrings.yesterdayAmount(rupiah(yesterday)) : DashboardStrings.periodStart,
                        style: TextStyle(
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.s16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate950.withValues(alpha: 0.6) : AppColors.slate50,
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                    border: Border.all(
                      color: isDark ? AppColors.slate800 : AppColors.slate200.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricSubItem(
                          label: DashboardStrings.metricTransactions,
                          value: '$count',
                          caption: count > 0 ? DashboardStrings.metricCompleted : DashboardStrings.metricEmptyValue,
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
                          label: DashboardStrings.metricAvgTicket,
                          value: count > 0 ? rupiah(avgTicket) : '-',
                          caption: DashboardStrings.metricCartValue,
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
                            label: DashboardStrings.metricGrossProfit,
                            value: rupiah(profit),
                            caption: profitMargin != null ? DashboardStrings.marginCaption(profitMargin) : DashboardStrings.afterCogs,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
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
          const SizedBox(height: AppSizes.s2),
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
          const SizedBox(height: AppSizes.s1),
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
