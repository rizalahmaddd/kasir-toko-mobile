import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/state_views.dart';
import '../data/product_models.dart';

class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    this.url,
    this.name,
    this.size = 44,
  });

  final String? url;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: name != null && name!.trim().isNotEmpty
          ? Text(
              name!.trim().characters.take(2).toString().toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              LucideIcons.package,
              size: size * 0.45,
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );

    return AppCachedImage(
      imageUrl: url,
      width: size,
      height: size,
      borderRadius: 8,
      memCacheWidth: (size * 2.5).toInt(),
      memCacheHeight: (size * 2.5).toInt(),
      fallback: fallback,
      placeholder: fallback,
    );
  }
}

class StockLabel extends StatelessWidget {
  const StockLabel({super.key, required this.product});

  final ProductRecord product;

  @override
  Widget build(BuildContext context) {
    if (!product.trackStock) {
      return const StatusBadge(label: 'Tanpa stok');
    }
    if (product.isOutOfStock) {
      return const StatusBadge(label: 'Habis', tone: BadgeTone.danger);
    }

    final colors = StatusColors.of(context);

    return Text(
      '${quantity(product.stock)} ${product.unit}',
      style: AppTypography.quantity(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: product.isLowStock ? colors.warning : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.onTap, this.showPrice = true});

  final ProductRecord product;
  final VoidCallback? onTap;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ProductThumb(url: product.imageUrl, name: product.name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          if (!product.isActive) ...[
                            const SizedBox(width: 6),
                            const StatusBadge(label: 'Nonaktif'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (product.category != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.category!.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (product.sku.isNotEmpty)
                            Flexible(
                              child: Text(
                                product.sku,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: muted, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showPrice)
                      Text(
                        rupiah(product.price),
                        style: AppTypography.money(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                      ),
                    const SizedBox(height: 3),
                    StockLabel(product: product),
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
