import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../sales/data/sale_models.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class RecentSalesSection extends StatelessWidget {
  const RecentSalesSection({super.key, required this.sales});

  final List<SaleSummary> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          DashboardStrings.recentSalesTitle,
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
            ),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              context.go(AppRoutes.sales);
            },
            icon: const Text(DashboardStrings.viewAllLabel, style: TextStyle(fontSize: 12)),
            label: const Icon(AppIcons.chevronRight, size: AppSizes.s14),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, sale) in sales.take(5).indexed) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    context.push(AppRoutes.saleDetail(sale.id));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s8),
                          decoration: BoxDecoration(
                            color: sale.isVoided
                                ? (isDark ? AppColors.rose500.withValues(alpha: 0.2) : AppColors.rose500.withValues(alpha: 0.1))
                                : (sale.dueAmount > 0
                                    ? (isDark ? AppColors.amber500.withValues(alpha: 0.2) : AppColors.amber500.withValues(alpha: 0.1))
                                    : (isDark ? AppColors.slate800 : AppColors.slate100)),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                          ),
                          child: Icon(
                            sale.isVoided
                                ? AppIcons.ban
                                : (sale.dueAmount > 0 ? AppIcons.handCoins : AppIcons.receipt),
                            size: AppSizes.s18,
                            color: sale.isVoided
                                ? (isDark ? AppColors.rose500 : AppColors.rose600)
                                : (sale.dueAmount > 0
                                    ? (isDark ? AppColors.amber500 : AppColors.amber600)
                                    : (isDark ? AppColors.slate300 : AppColors.slate700)),
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
                                      sale.number,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.s6),
                                  if (sale.isVoided)
                                    const StatusBadge(label: DashboardStrings.statusVoided, tone: BadgeTone.danger)
                                  else if (sale.dueAmount > 0)
                                    const StatusBadge(label: DashboardStrings.statusReceivable, tone: BadgeTone.warning),
                                ],
                              ),
                              const SizedBox(height: AppSizes.s2),
                              Text(
                                DashboardStrings.saleMetaLine(timeOnly(sale.soldAt), sale.itemsCount, sale.customer?.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSizes.s8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              rupiah(sale.total),
                              style: AppTypography.money(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sale.isVoided ? muted : (isDark ? Colors.white : AppColors.slate900),
                                decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (sale.paymentMethods.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.s2),
                                child: Text(
                                  sale.paymentMethods.first,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
