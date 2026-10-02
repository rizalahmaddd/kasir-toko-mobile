import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../../products/data/product_models.dart';
import '../../../products/presentation/product_widgets.dart';

class LowStockSection extends StatelessWidget {
  const LowStockSection({super.key, required this.products});

  final List<ProductRecord> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.slate800 : AppColors.slate200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.checkCircle2,
                size: 18,
                color: AppColors.emerald500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stok Produk Aman',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate200 : AppColors.slate800,
                    ),
                  ),
                  Text(
                    'Tidak ada produk di bawah batas stok minimum',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                context.push('/stock');
              },
              child: const Text('Cek Stok', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Stok Menipis & Habis',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              context.push('/stock');
            },
            icon: Text(
              'Lihat semua (${products.length})',
              style: const TextStyle(fontSize: 12),
            ),
            label: const Icon(LucideIcons.chevronRight, size: 14),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final (i, product) in products.take(5).indexed) ...[
                if (i > 0) const Divider(height: 1),
                ProductTile(
                  product: product,
                  showPrice: true,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    context.push('/product/${product.id}');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
