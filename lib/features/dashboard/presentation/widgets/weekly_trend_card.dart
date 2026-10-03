import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/bar_chart.dart';
import '../../../auth/access.dart';
import '../../../auth/auth_controller.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class WeeklyTrendCard extends ConsumerWidget {
  const WeeklyTrendCard({super.key, required this.points});

  final List<({String label, num value})> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    final total = points.fold<num>(0, (sum, p) => sum + p.value);
    final avg = points.isNotEmpty ? total / points.length : 0;
    final peak = points.reduce((best, curr) => curr.value > best.value ? curr : best);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DashboardStrings.weeklyTrendTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.slate200 : AppColors.slate800,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s2),
                      Text(
                        DashboardStrings.weeklyTotal(rupiah(total)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (user?.canViewSalesReport ?? false)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      context.push(AppRoutes.reportsSales);
                    },
                    icon: const Text(DashboardStrings.detailLabel, style: TextStyle(fontSize: 12)),
                    label: const Icon(AppIcons.chevronRight, size: AppSizes.s14),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.s12),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s6),
              child: SimpleBarChart(points: points, height: 160, highlightLast: true),
            ),
            const SizedBox(height: AppSizes.s12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate950 : AppColors.slate50,
                borderRadius: BorderRadius.circular(AppRadius.r10),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.sparkles,
                    size: AppSizes.s14,
                    color: isDark ? AppColors.emerald400 : AppColors.emerald700,
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: Text(
                      peak.value > 0
                          ? DashboardStrings.weeklyPeak(peak.label, rupiah(peak.value), rupiah(avg))
                          : DashboardStrings.weeklyAverage(rupiah(avg)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
