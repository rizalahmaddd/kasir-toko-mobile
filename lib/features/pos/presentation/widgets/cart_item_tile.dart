import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/widgets/state_views.dart';
import '../../cart_controller.dart';
import '../../data/pos_models.dart';
import 'cart_line_edit_sheet.dart';

class CartItemTile extends ConsumerWidget {
  const CartItemTile({super.key, required this.item, required this.canDiscount});

  final CartItem item;
  final bool canDiscount;

  void _onQuantityChanged(BuildContext context, WidgetRef ref, double newQty) {
    final warning = ref.read(cartProvider.notifier).setQuantity(item.productId, newQty);
    if (warning != null) {
      unawaited(HapticFeedback.heavyImpact());
      showMessage(context, warning, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final colors = StatusColors.of(context);

    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        CartLineEditSheet.show(context, item, canDiscount: canDiscount);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      height: 1.25,
                      color: isDark ? AppColors.slate100 : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${rupiah(item.price)} / ${item.unit}',
                        style: AppTypography.money(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                      if (item.appliedDiscount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Diskon -${rupiah(item.appliedDiscount)}',
                            style: AppTypography.money(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(LucideIcons.fileText, size: 12, color: isDark ? AppColors.slate400 : AppColors.slate500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.slate400 : AppColors.slate600,
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.exceedsStock) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Stok tersisa ${quantity(item.stock)}',
                        style: TextStyle(
                          color: colors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupiah(item.total),
                  style: AppTypography.money(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 6),
                QuantityStepper(
                  value: item.quantity,
                  onChanged: (newQty) => _onQuantityChanged(context, ref, newQty),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
