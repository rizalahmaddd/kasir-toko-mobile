import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/widgets/state_views.dart';
import '../../cart_controller.dart';
import '../../data/pos_models.dart';
import '../pos_actions.dart';
import 'cart_line_edit_sheet.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class CartItemTile extends ConsumerWidget {
  const CartItemTile({super.key, required this.item, required this.canDiscount});

  final CartItem item;
  final bool canDiscount;

  void _onQuantityChanged(BuildContext context, WidgetRef ref, double newQty) {
    // Unit bernomor seri bertambah lewat pemilihan nomor seri, bukan tombol plus.
    if (item.trackSerial && newQty > item.quantity) {
      unawaited(editLineSerials(context, ref, item));
      return;
    }
    final warning = ref.read(cartProvider.notifier).setQuantity(item.key, newQty);
    if (warning != null) {
      unawaited(HapticFeedback.heavyImpact());
      showMessage(context, warning, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final colors = StatusColors.of(context);

    final nameInitials = item.name.trim().isNotEmpty
        ? item.name.trim().characters.take(2).toString().toUpperCase()
        : PosStrings.productInitialsFallback;

    return Dismissible(
      key: ValueKey('cart_item_${item.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.s20),
        color: AppColors.rose600,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.trash2, color: Colors.white, size: AppSizes.s20),
            SizedBox(width: AppSizes.s6),
            Text(
              PosStrings.delete,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        unawaited(HapticFeedback.mediumImpact());
        ref.read(cartProvider.notifier).remove(item.key);
      },
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          CartLineEditSheet.show(context, item, canDiscount: canDiscount);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? AppCachedImage(
                          imageUrl: item.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate100,
                            border: Border.all(
                              color: isDark ? AppColors.slate700 : AppColors.slate200,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            nameInitials,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark ? AppColors.slate300 : AppColors.slate600,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSizes.s10),
              // Item Details
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        if (item.requiresPrescription)
                          TextSpan(
                            text: '${PosStrings.prescriptionBadge} ',
                            style: TextStyle(color: colors.danger, fontWeight: FontWeight.w800),
                          ),
                        TextSpan(text: item.name),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      height: 1.25,
                      color: isDark ? AppColors.slate100 : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s3),
                  Row(
                    children: [
                      Text(
                        PosStrings.pricePerUnit(rupiah(item.unitPrice + item.modifiersTotal), item.unit),
                        style: AppTypography.money(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                      if (item.isTiered) ...[
                        const SizedBox(width: AppSizes.s6),
                        Text(
                          PosStrings.tierBadge,
                          style: theme.textTheme.labelSmall?.copyWith(color: colors.warning, fontWeight: FontWeight.w800, fontSize: 10),
                        ),
                      ],
                      if (item.appliedDiscount > 0) ...[
                        const SizedBox(width: AppSizes.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: AppSpacing.s1_5),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.r4),
                          ),
                          child: Text(
                            PosStrings.itemDiscount(rupiah(item.appliedDiscount)),
                            style: AppTypography.money(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.trackSerial) ...[
                    const SizedBox(height: AppSizes.s3),
                    Text(
                      item.serials.isEmpty ? PosStrings.serialPick : 'SN: ${item.serials.join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: item.needsSerials ? colors.warning : muted,
                        fontSize: 11,
                        fontWeight: item.needsSerials ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                  if (item.modifiers.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.s3),
                    Text(
                      item.modifierNames,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.info, fontSize: 11),
                    ),
                  ],
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.s3),
                    Row(
                      children: [
                        Icon(AppIcons.fileText, size: AppSizes.s12, color: isDark ? AppColors.slate400 : AppColors.slate500),
                        const SizedBox(width: AppSizes.s4),
                        Expanded(
                          child: Text(
                            item.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.slate400 : AppColors.slate600,
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.exceedsStock) ...[
                    const SizedBox(height: AppSizes.s3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                      ),
                      child: Text(
                        PosStrings.stockRemainingShort(quantity(item.stock)),
                        style: TextStyle(
                          color: colors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupiah(item.total),
                  style: AppTypography.money(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: AppSizes.s6),
                QuantityStepper(
                  value: item.quantity,
                  onChanged: (newQty) => _onQuantityChanged(context, ref, newQty),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
