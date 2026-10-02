import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pos_models.dart';
import 'cart_discount_sheet.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _SummaryRow('Subtotal', rupiah(totals.subtotal)),
                if (canDiscount)
                  InkWell(
                    onTap: cart.isEmpty
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            CartDiscountSheet.show(context);
                          },
                    borderRadius: BorderRadius.circular(6),
                    child: _SummaryRow(
                      cart.discountType == DiscountType.percent
                          ? 'Diskon ${quantity(cart.discountValue)}%'
                          : 'Diskon',
                      totals.discountAmount > 0 ? '-${rupiah(totals.discountAmount)}' : 'Atur Diskon >',
                      valueColor: totals.discountAmount > 0 ? AppColors.emerald500 : theme.colorScheme.primary,
                    ),
                  )
                else if (totals.discountAmount > 0)
                  _SummaryRow('Diskon', '-${rupiah(totals.discountAmount)}', valueColor: AppColors.emerald500),
                if ((config?.taxRate ?? 0) > 0)
                  _SummaryRow('${config!.taxLabel} ${quantity(config!.taxRate)}%', rupiah(totals.taxAmount)),
                const SizedBox(height: 6),
                Divider(
                  height: 12,
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.slate100 : AppColors.slate900,
                          ),
                        ),
                        Text(
                          '${quantity(cart.itemCount)} barang',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      rupiah(totals.total),
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
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          unawaited(HapticFeedback.lightImpact());
                          onHold();
                        },
                  icon: const Icon(LucideIcons.pause, size: 18),
                  label: const Text('Tunda'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: cart.isEmpty || config == null
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            onPay();
                          },
                    icon: const Icon(LucideIcons.checkCheck, size: 20),
                    label: Text(
                      'Bayar ${rupiah(totals.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
  const _SummaryRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
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
