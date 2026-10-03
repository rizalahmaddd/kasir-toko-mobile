import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/payment_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../data/sale_models.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';

class SaleTile extends StatelessWidget {
  const SaleTile({
    super.key,
    required this.sale,
    this.margin,
  });

  final SaleSummary sale;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isToday = DateUtils.isSameDay(sale.soldAt, DateTime.now());

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r14),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r14),
          onTap: () => context.push(AppRoutes.saleDetail(sale.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row: Invoice Number & Timestamp
                Row(
                  children: [
                    Icon(
                      AppIcons.receipt,
                      size: AppSizes.s13,
                      color: muted,
                    ),
                    const SizedBox(width: AppSizes.s6),
                    Text(
                      sale.number,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate300 : AppColors.slate600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      AppIcons.clock,
                      size: AppSizes.s12,
                      color: muted,
                    ),
                    const SizedBox(width: AppSizes.s4),
                    Text(
                      isToday ? timeOnly(sale.soldAt) : SalesStrings.soldAtStamp(dateOnly(sale.soldAt), timeOnly(sale.soldAt)),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s9),
                  child: Divider(
                    height: 1,
                    thickness: 0.8,
                    color: isDark ? AppColors.slate700 : AppColors.slate100,
                  ),
                ),

                // Main row: Customer & Items on Left, Amount & Status on Right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.customer?.name ?? SalesStrings.generalCustomer,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSizes.s6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                SalesStrings.goodsCount(sale.itemsCount),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              for (final method in sale.paymentMethods)
                                PaymentBadge(method: method),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rupiah(sale.total),
                          style: AppTypography.money(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sale.isVoided
                                ? muted
                                : sale.dueAmount > 0
                                    ? AppColors.amber600
                                    : AppColors.emerald600,
                            decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: AppSizes.s4),
                        if (sale.isVoided)
                          const StatusBadge(label: SalesStrings.statusVoided, tone: BadgeTone.danger)
                        else if (sale.dueAmount > 0) ...[
                          const StatusBadge(label: SalesStrings.statusCredit, tone: BadgeTone.warning),
                          const SizedBox(height: AppSizes.s2),
                          Text(
                            SalesStrings.remainingAmount(rupiah(sale.dueAmount)),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.amber600,
                            ),
                          ),
                        ] else
                          const StatusBadge(label: SalesStrings.statusCompleted, tone: BadgeTone.success),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

