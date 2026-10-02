import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../data/product_models.dart';

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
      'stock_in' => LucideIcons.arrowDownToLine,
      'stock_out' => LucideIcons.arrowUpFromLine,
      'sale' => LucideIcons.shoppingBag,
      'opname' => LucideIcons.clipboardCheck,
      _ => delta >= 0 ? LucideIcons.arrowDownToLine : LucideIcons.arrowUpFromLine,
    };

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            movement.typeLabel,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      dateTime(movement.createdAt),
                      if (movement.userName != null) 'Oleh ${movement.userName}',
                      if (movement.note != null && movement.note!.isNotEmpty) movement.note!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : ''}${quantity(delta)}',
                  style: AppTypography.quantity(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${quantity(movement.stockBefore)} → ${quantity(movement.stockAfter)}',
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
