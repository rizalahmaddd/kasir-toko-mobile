import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/bar_chart.dart';
import '../../../auth/access.dart';
import '../../../auth/auth_controller.dart';

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        'Tren Omzet 7 Hari',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.slate200 : AppColors.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total 7 hari: ${rupiah(total)}',
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      context.push('/reports/sales');
                    },
                    icon: const Text('Detail', style: TextStyle(fontSize: 12)),
                    label: const Icon(LucideIcons.chevronRight, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SimpleBarChart(points: points, height: 160, highlightLast: true),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate950 : AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    size: 14,
                    color: isDark ? AppColors.emerald400 : AppColors.emerald700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      peak.value > 0
                          ? 'Tertinggi: ${peak.label} (${rupiah(peak.value)}) · Rata-rata ${rupiah(avg)}/hari'
                          : 'Rata-rata omzet harian: ${rupiah(avg)}',
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
