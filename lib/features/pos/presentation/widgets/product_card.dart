import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../data/pos_models.dart';

class PosProductCard extends ConsumerWidget {
  const PosProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLongPress,
    this.inCartQuantity = 0,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double inCartQuantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isOutOfStock = product.isOutOfStock;
    final hasInCart = inCartQuantity > 0;

    final nameInitials = product.name.trim().isNotEmpty
        ? product.name.trim().characters.take(2).toString().toUpperCase()
        : 'IT';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasInCart
              ? theme.colorScheme.primary
              : (isDark ? AppColors.slate800 : AppColors.slate200),
          width: hasInCart ? 1.8 : 1,
        ),
        boxShadow: hasInCart
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: isDark ? Colors.black26 : AppColors.slate900.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (!isOutOfStock) {
              unawaited(HapticFeedback.selectionClick());
            }
            onTap();
          },
          onLongPress: isOutOfStock ? null : onLongPress,
          child: Opacity(
            opacity: isOutOfStock ? 0.65 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Photo Container
                SizedBox(
                  height: 114,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppCachedImage(
                        imageUrl: product.imageUrl,
                        height: 114,
                        width: double.infinity,
                        borderRadius: 13,
                        memCacheWidth: 350,
                        fallback: _ProductPlaceholder(
                          initials: nameInitials,
                          sku: product.sku,
                        ),
                      ),

                      // Low stock indicator badge
                      if (product.isLowStock && !isOutOfStock)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.amber500,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.triangleAlert, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  'Sisa ${quantity(product.stock)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Out of stock overlay
                      if (isOutOfStock)
                        Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                            child: const Text(
                              'HABIS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),

                      // Floating in-cart quantity badge
                      if (hasInCart)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '${quantity(inCartQuantity)}×',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Product Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Uniform 2-line title slot
                        SizedBox(
                          height: 34,
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              fontSize: 12.5,
                              color: isDark ? AppColors.slate100 : AppColors.slate800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (product.sku != null && product.sku!.isNotEmpty)
                          Text(
                            product.sku!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      rupiah(product.price),
                                      style: AppTypography.money(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  if (isOutOfStock)
                                    Text(
                                      'Habis',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: colors.danger,
                                      ),
                                    )
                                  else if (product.trackStock)
                                    Text(
                                      '${quantity(product.stock)} ${product.unit}',
                                      style: AppTypography.quantity(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: product.isLowStock ? colors.warning : muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: hasInCart
                                    ? theme.colorScheme.primary
                                    : (isDark ? AppColors.slate800 : AppColors.slate100),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasInCart ? LucideIcons.check : LucideIcons.plus,
                                size: 14,
                                color: hasInCart
                                    ? Colors.white
                                    : (isDark ? AppColors.slate300 : AppColors.slate700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder({required this.initials, this.sku});

  final String initials;
  final String? sku;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (sku != null && sku!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              sku!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: muted.withValues(alpha: 0.8),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
