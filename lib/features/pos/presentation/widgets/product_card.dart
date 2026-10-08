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

class PosProductCard extends ConsumerWidget {
  const PosProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLongPress,
    this.inCartQuantity = 0,
    this.onDecrement,
    this.onEditQuantity,
    this.isLarge = false,
    this.customPhotoHeight,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double inCartQuantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onEditQuantity;
  final bool isLarge;
  final double? customPhotoHeight;

  bool get isCompact => (customPhotoHeight ?? (isLarge ? 155.0 : 114.0)) < 105.0;

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

    final photoHeight = customPhotoHeight ?? (isLarge ? 155.0 : 114.0);
    final isCompact = photoHeight < 105.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r14),
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
        borderRadius: BorderRadius.circular(AppRadius.r14),
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
                  height: photoHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppCachedImage(
                        imageUrl: product.imageUrl,
                        height: photoHeight,
                        width: double.infinity,
                        borderRadius: 13,
                        memCacheWidth: isLarge ? 480 : 350,
                        fallback: _ProductPlaceholder(
                          initials: nameInitials,
                          sku: product.sku,
                        ),
                      ),

                      // Negative stock indicator badge
                      if (isNegativeStock)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2_5),
                            decoration: BoxDecoration(
                              color: AppColors.rose500,
                              borderRadius: BorderRadius.circular(AppRadius.r6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(AppIcons.triangleAlert, size: AppSizes.s10, color: Colors.white),
                                const SizedBox(width: AppSizes.s3),
                                Text(
                                  PosStrings.stockBadge(quantity(product.stock)),
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

                      // Low stock indicator badge
                      if (isLowStock)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2_5),
                            decoration: BoxDecoration(
                              color: AppColors.amber500,
                              borderRadius: BorderRadius.circular(AppRadius.r6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(AppIcons.triangleAlert, size: AppSizes.s10, color: Colors.white),
                                const SizedBox(width: AppSizes.s3),
                                Text(
                                  PosStrings.stockLowBadge(quantity(product.stock)),
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
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s3_5),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(AppRadius.r6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                            child: const Text(
                              PosStrings.outOfStockBadge,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),

                      // Capability Micro-Badges (Varian, Opsi, SN, Satuan)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (product.variants.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.sky500,
                                  borderRadius: BorderRadius.circular(AppRadius.r4),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                ),
                                child: const Text('Varian', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                              )
                            else if (product.modifierGroups.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.indigo500,
                                  borderRadius: BorderRadius.circular(AppRadius.r4),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                ),
                                child: const Text('Opsi', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                              ),
                            if (product.trackSerial)
                              Container(
                                margin: const EdgeInsets.only(right: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade600,
                                  borderRadius: BorderRadius.circular(AppRadius.r4),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                ),
                                child: const Text('SN', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                              ),
                            if (product.units.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald600,
                                  borderRadius: BorderRadius.circular(AppRadius.r4),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                ),
                                child: const Text('Satuan', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                      ),

                      // Floating in-cart quantity stepper / badge
                      if (hasInCart)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.r12),
                            elevation: 3,
                            shadowColor: Colors.black45,
                            clipBehavior: Clip.antiAlias,
                            child: onDecrement != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Minus or Trash icon button
                                      InkWell(
                                        onTap: () {
                                          unawaited(HapticFeedback.selectionClick());
                                          onDecrement!();
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isLarge ? 9 : (isCompact ? 5 : 7),
                                            vertical: isLarge ? 6 : (isCompact ? 3 : 4),
                                          ),
                                          child: Icon(
                                            inCartQuantity <= 1 ? AppIcons.trash2 : AppIcons.minus,
                                            size: isLarge ? 15 : (isCompact ? 11 : 13),
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      // Quantity (tappable to edit or delete)
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
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isLarge ? 5 : (isCompact ? 3 : 3),
                                            vertical: isLarge ? 6 : (isCompact ? 3 : 4),
                                          ),
                                          child: Text(
                                            quantity(inCartQuantity),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: isLarge ? 13 : (isCompact ? 10.5 : 11.5),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Plus / Add button
                                      InkWell(
                                        onTap: () {
                                          if (!isOutOfStock) {
                                            unawaited(HapticFeedback.selectionClick());
                                          }
                                          onTap();
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isLarge ? 9 : (isCompact ? 5 : 7),
                                            vertical: isLarge ? 6 : (isCompact ? 3 : 4),
                                          ),
                                          child: Icon(
                                            AppIcons.plus,
                                            size: isLarge ? 15 : (isCompact ? 11 : 13),
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isCompact ? 5 : AppSpacing.s7,
                                      vertical: isCompact ? 2.5 : AppSpacing.s3,
                                    ),
                                    child: Text(
                                      PosStrings.inCartBadge(quantity(inCartQuantity)),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isLarge ? 12 : (isCompact ? 10 : 11),
                                        fontWeight: FontWeight.w800,
                                      ),
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
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? AppSpacing.s6 : AppSpacing.s9,
                      isCompact ? AppSpacing.s5 : AppSpacing.s7,
                      isCompact ? AppSpacing.s6 : AppSpacing.s9,
                      isCompact ? AppSpacing.s5 : AppSpacing.s8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Uniform 2-line title slot
                        SizedBox(
                          height: isLarge ? 36 : (isCompact ? 28 : 34),
                          child: Text(
                            product.requiresPrescription ? '${PosStrings.prescriptionBadge} · ${product.name}' : product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.18,
                              fontSize: isLarge ? 13.5 : (isCompact ? 11.0 : 12.5),
                              color: isDark ? AppColors.slate100 : AppColors.slate800,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.s2),
                        if (product.sku != null && product.sku!.isNotEmpty)
                          Text(
                            product.sku!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                              fontSize: isLarge ? 11 : (isCompact ? 8.5 : 10),
                              fontFamily: AppFonts.monospace,
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
                                        fontSize: isLarge ? 16 : (isCompact ? 12.0 : 14.0),
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  if (isOutOfStock)
                                    Text(
                                      PosStrings.outOfStockLabel,
                                      style: TextStyle(
                                        fontSize: isLarge ? 11 : (isCompact ? 9.5 : 10.5),
                                        fontWeight: FontWeight.w700,
                                        color: colors.danger,
                                      ),
                                    )
                                  else if (isNegativeStock)
                                    Text(
                                      PosStrings.negativeStockLabel(quantity(product.stock), product.unit),
                                      style: TextStyle(
                                        fontSize: isLarge ? 11 : (isCompact ? 9.5 : 10.5),
                                        fontWeight: FontWeight.w700,
                                        color: colors.danger,
                                      ),
                                    )
                                  else if (product.trackStock)
                                    Text(
                                      PosStrings.onHandQuantity(quantity(product.stock), product.unit),
                                      style: AppTypography.quantity(
                                        fontSize: isLarge ? 11 : (isCompact ? 9.5 : 10.5),
                                        fontWeight: FontWeight.w600,
                                        color: isLowStock ? colors.warning : muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: isLarge ? 32 : (isCompact ? 22 : 26),
                              height: isLarge ? 32 : (isCompact ? 22 : 26),
                              decoration: BoxDecoration(
                                color: hasInCart
                                    ? theme.colorScheme.primary
                                    : (isDark ? AppColors.slate800 : AppColors.slate100),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasInCart
                                    ? AppIcons.check
                                    : (product.variants.isNotEmpty || product.modifierGroups.isNotEmpty
                                        ? AppIcons.slidersHorizontal
                                        : AppIcons.plus),
                                size: isLarge ? AppSizes.s16 : (isCompact ? 11 : AppSizes.s14),
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
              borderRadius: BorderRadius.circular(AppRadius.r10),
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
            const SizedBox(height: AppSizes.s5),
            Text(
              sku!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: muted.withValues(alpha: 0.8),
                fontFamily: AppFonts.monospace,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
