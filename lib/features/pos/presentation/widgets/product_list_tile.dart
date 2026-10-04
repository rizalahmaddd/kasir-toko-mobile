import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_fonts.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../data/pos_models.dart';
import '../../pos_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class PosProductListTile extends ConsumerWidget {
  const PosProductListTile({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLongPress,
    this.inCartQuantity = 0,
    this.onDecrement,
    this.onEditQuantity,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double inCartQuantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onEditQuantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final allowNegative = ref.watch(posConfigProvider).value?.allowNegativeStock ?? false;
    final isOutOfStock = product.isOutOfStock && !allowNegative;
    final isNegativeStock = product.trackStock && product.stock <= 0 && allowNegative;
    final isLowStock = product.isLowStock && !isOutOfStock && !isNegativeStock;
    final hasInCart = inCartQuantity > 0;

    final nameInitials = product.name.trim().isNotEmpty
        ? product.name.trim().characters.take(2).toString().toUpperCase()
        : PosStrings.productInitialsFallback;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: hasInCart
              ? theme.colorScheme.primary
              : (isDark ? AppColors.slate800 : AppColors.slate200),
          width: hasInCart ? 1.5 : 1,
        ),
        boxShadow: hasInCart
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: isDark ? Colors.black12 : AppColors.slate900.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r12),
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
            opacity: isOutOfStock ? 0.6 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
              child: Row(
                children: [
                  // Thumbnail Photo (44x44)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      children: [
                        AppCachedImage(
                          imageUrl: product.imageUrl,
                          width: 44,
                          height: 44,
                          borderRadius: 8,
                          memCacheWidth: 120,
                          fallback: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate800 : AppColors.slate100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              nameInitials,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.slate400 : AppColors.slate600,
                              ),
                            ),
                          ),
                        ),
                        if (isOutOfStock)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              PosStrings.outOfStockBadge,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSizes.s10),

                  // Middle: Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: isDark ? AppColors.slate100 : AppColors.slate800,
                          ),
                        ),
                        const SizedBox(height: AppSizes.s2),
                        Row(
                          children: [
                            if (product.sku != null && product.sku!.isNotEmpty) ...[
                              Text(
                                product.sku!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                                  fontSize: 10.5,
                                  fontFamily: AppFonts.monospace,
                                ),
                              ),
                              const SizedBox(width: AppSizes.s4),
                              Text('·', style: TextStyle(color: muted, fontSize: 11)),
                              const SizedBox(width: AppSizes.s4),
                            ],
                            if (isOutOfStock)
                              Text(
                                PosStrings.outOfStockLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.danger,
                                ),
                              )
                            else if (isNegativeStock)
                              Text(
                                PosStrings.negativeStockLabel(quantity(product.stock), product.unit),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.danger,
                                ),
                              )
                            else if (product.trackStock)
                              Text(
                                PosStrings.onHandQuantity(quantity(product.stock), product.unit),
                                style: AppTypography.quantity(
                                  fontSize: 11,
                                  fontWeight: isLowStock ? FontWeight.w700 : FontWeight.w500,
                                  color: isLowStock ? colors.warning : muted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSizes.s8),

                  // Right: Price & Stepper or Add Button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        rupiah(product.price),
                        style: AppTypography.money(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s4),
                      if (hasInCart)
                        Material(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  onDecrement?.call();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: Icon(
                                    inCartQuantity <= 1 ? AppIcons.trash2 : AppIcons.minus,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  if (onEditQuantity != null) {
                                    onEditQuantity!();
                                  } else {
                                    onLongPress();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                  child: Text(
                                    quantity(inCartQuantity),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  if (!isOutOfStock) {
                                    unawaited(HapticFeedback.selectionClick());
                                  }
                                  onTap();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: Icon(
                                    AppIcons.plus,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.plus,
                            size: AppSizes.s14,
                            color: isDark ? AppColors.slate300 : AppColors.slate700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
