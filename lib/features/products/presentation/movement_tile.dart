import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../data/product_models.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
    required this.movement,
    this.showProduct = false,
    this.margin,
  });

  final StockMovement movement;
  final bool showProduct;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final delta = movement.delta;
    final isPositive = delta > 0;
    final isNegative = delta < 0;
    final color = isPositive ? colors.success : (isNegative ? colors.warning : muted);

    final icon = switch (movement.type) {
      MovementTypes.stockIn => AppIcons.arrowDownToLine,
      MovementTypes.stockOut => AppIcons.arrowUpFromLine,
      MovementTypes.sale => AppIcons.shoppingBag,
      MovementTypes.opname => AppIcons.clipboardCheck,
      _ => delta >= 0 ? AppIcons.arrowDownToLine : AppIcons.arrowUpFromLine,
    };

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.r10),
              ),
              child: Icon(icon, size: AppSizes.s18, color: color),
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
                          showProduct ? movement.productName : movement.typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                      if (showProduct) ...[
                        const SizedBox(width: AppSizes.s6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s1_5),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate700 : AppColors.slate100,
                            borderRadius: BorderRadius.circular(AppRadius.r4),
                          ),
                          child: Text(
                            movement.typeLabel,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSizes.s3),
                  Text(
                    [
                      dateTime(movement.createdAt),
                      if (movement.userName != null) ProductStrings.movementByUser(movement.userName!),
                      if (movement.note != null && movement.note!.isNotEmpty) movement.note!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.s10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ProductStrings.movementDelta(isPositive, quantity(delta)),
                  style: AppTypography.quantity(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSizes.s2),
                Text(
                  ProductStrings.movementStockRange(quantity(movement.stockBefore), quantity(movement.stockAfter)),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
