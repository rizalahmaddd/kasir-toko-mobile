import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../data/product_models.dart';

class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, this.url, this.size = 44});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
      child: Icon(LucideIcons.package, size: size * 0.45, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );

    if (url == null) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(imageUrl: url!, width: size, height: size, fit: BoxFit.cover, errorWidget: (_, _, _) => placeholder),
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
      style: TextStyle(
        fontSize: 13,
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final details = [product.sku, ?product.category?.name].join(' · ');

    return ListTile(
      onTap: onTap,
      leading: ProductThumb(url: product.imageUrl),
      title: Row(
        children: [
          Flexible(child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (!product.isActive) ...[const SizedBox(width: 6), const StatusBadge(label: 'Nonaktif')],
        ],
      ),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showPrice) Text(rupiah(product.price), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          StockLabel(product: product),
        ],
      ),
    );
  }
}
