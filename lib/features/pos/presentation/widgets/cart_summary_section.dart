import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pos_models.dart';
import 'cart_discount_sheet.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class CartSummarySection extends StatelessWidget {
  const CartSummarySection({
    super.key,
    required this.cart,
    required this.config,
    required this.totals,
    required this.onHold,
    required this.onPay,
  });

  final Cart cart;
  final PosConfig? config;
  final CartTotals totals;
  final VoidCallback onHold;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final canDiscount = config?.canDiscount ?? false;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s8),
            child: Column(
              children: [
                _SummaryRow(PosStrings.subtotalLabel, rupiah(totals.subtotal)),
                if (canDiscount)
                  InkWell(
                    onTap: cart.isEmpty
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            CartDiscountSheet.show(context);
                          },
                    borderRadius: BorderRadius.circular(AppRadius.r6),
                    child: _SummaryRow(
                      cart.discountType == DiscountType.percent
                          ? PosStrings.discountPercentLabel(quantity(cart.discountValue))
                          : PosStrings.discountLabel,
                      totals.discountAmount > 0 ? PosStrings.discountAmountValue(rupiah(totals.discountAmount)) : PosStrings.setDiscountLink,
                      valueColor: totals.discountAmount > 0 ? AppColors.emerald500 : theme.colorScheme.primary,
                      icon: AppIcons.tag,
                    ),
                  )
                else if (totals.discountAmount > 0)
                  _SummaryRow(
                    PosStrings.discountLabel,
                    PosStrings.discountAmountValue(rupiah(totals.discountAmount)),
                    valueColor: AppColors.emerald500,
                    icon: AppIcons.tag,
                  ),
                if (totals.serviceAmount > 0)
                  _SummaryRow(PosStrings.serviceLabel(quantity(config!.serviceRateFor(cart.orderTypeFor(config)))), rupiah(totals.serviceAmount)),
                if ((config?.taxRate ?? 0) > 0) _SummaryRow(PosStrings.taxLabelRate(config!.taxLabel, quantity(config!.taxRate)), rupiah(totals.taxAmount)),
                const SizedBox(height: AppSizes.s6),
                Divider(
                  height: 12,
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                ),
                const SizedBox(height: AppSizes.s4),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PosStrings.totalLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.slate100 : AppColors.slate900,
                          ),
                        ),
                        Text(
                          cart.customerOrder == null ? PosStrings.cartItemCount(quantity(cart.itemCount)) : PosStrings.amountDueLabel(rupiah(cart.customerOrder!.deposit)),
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      rupiah(cart.amountDue(config)),
                      style: AppTypography.money(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s0, AppSpacing.s14, AppSpacing.s14),
            child: Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                  ),
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          unawaited(HapticFeedback.lightImpact());
                          onHold();
                        },
                  icon: const Icon(AppIcons.pause, size: AppSizes.s18),
                  label: const Text(PosStrings.holdButton),
                ),
                const SizedBox(width: AppSizes.s10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                      boxShadow: cart.isEmpty || config == null
                          ? null
                          : [
                              BoxShadow(
                                color: (isDark ? AppColors.emerald600 : AppColors.emerald500).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? AppColors.emerald600 : AppColors.emerald500,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                      ),
                      onPressed: cart.isEmpty || config == null
                          ? null
                          : () {
                              unawaited(HapticFeedback.lightImpact());
                              onPay();
                            },
                      icon: const Icon(AppIcons.checkCheck, size: AppSizes.s20),
                      label: Text(
PosStrings.payAmountButton(rupiah(cart.amountDue(config))),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.valueColor, this.icon});

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: valueColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSizes.s6),
          ],
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}
