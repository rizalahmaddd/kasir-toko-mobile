import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../products/data/product_models.dart';
import '../../../products/presentation/product_widgets.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class LowStockSection extends StatelessWidget {
  const LowStockSection({super.key, required this.products});

  final List<ProductRecord> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final colors = StatusColors.of(context);

    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.r14),
          border: Border.all(
            color: isDark ? AppColors.slate800 : AppColors.slate200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.checkCircle2,
                size: AppSizes.s18,
                color: AppColors.emerald500,
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DashboardStrings.stockSafeTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate200 : AppColors.slate800,
                    ),
                  ),
                  Text(
                    DashboardStrings.stockSafeSubtitle,
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              ),
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                context.push(AppRoutes.stock);
              },
              child: const Text(DashboardStrings.checkStockButton, style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          DashboardStrings.lowStockTitle,
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
            ),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              context.push(AppRoutes.stock);
            },
            icon: Text(
              DashboardStrings.viewAllProducts(products.length),
              style: const TextStyle(fontSize: 12),
            ),
            label: const Icon(AppIcons.chevronRight, size: AppSizes.s14),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, product) in products.take(5).indexed) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    context.push(AppRoutes.productDetail(product.id));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                    child: Row(
                      children: [
                        ProductThumb(
                          url: product.imageUrl,
                          name: product.name,
                          size: 40,
                        ),
                        const SizedBox(width: AppSizes.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: AppSizes.s2),
                              Row(
                                children: [
                                  if (product.category != null) ...[
                                    Flexible(
                                      child: Text(
                                        product.category!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: muted, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.s6),
                                    Text('·', style: TextStyle(color: muted, fontSize: 12)),
                                    const SizedBox(width: AppSizes.s6),
                                  ],
                                  Text(
                                    rupiah(product.price),
                                    style: AppTypography.money(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSizes.s8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (product.isOutOfStock)
                              const StatusBadge(label: ProductStrings.statusOutOfStock, tone: BadgeTone.danger)
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                                decoration: BoxDecoration(
                                  color: colors.warning.withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.r6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.alertTriangle, size: AppSizes.s12, color: colors.warning),
                                    const SizedBox(width: AppSizes.s4),
                                    Text(
                                      'Sisa ${quantity(product.stock)} ${product.unit}',
                                      style: TextStyle(
                                        color: colors.warning,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (product.minStock > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.s2),
                                child: Text(
                                  'Min: ${quantity(product.minStock)} ${product.unit}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSizes.s4),
                        Icon(AppIcons.chevronRight, size: AppSizes.s14, color: isDark ? AppColors.slate500 : AppColors.slate400),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
