import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/product_models.dart';

class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.movement, this.showProduct = false});

  final StockMovement movement;
  final bool showProduct;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final delta = movement.delta;
    final color = delta > 0 ? colors.success : (delta < 0 ? colors.warning : muted);
    final details = [dateTime(movement.createdAt), ?movement.userName, if (movement.note != null && movement.note!.isNotEmpty) movement.note!];

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(delta >= 0 ? LucideIcons.arrowDownToLine : LucideIcons.arrowUpFromLine, size: 16, color: color),
      ),
      title: Text(showProduct ? movement.productName : movement.typeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [if (showProduct) movement.typeLabel, ...details].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: muted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${delta > 0 ? '+' : ''}${quantity(delta)}', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          Text('${quantity(movement.stockBefore)} → ${quantity(movement.stockAfter)}', style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}
