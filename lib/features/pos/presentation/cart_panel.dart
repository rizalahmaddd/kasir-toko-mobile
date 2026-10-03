import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../offline/offline_queue.dart';
import '../../offline/presentation/offline_checkout_success.dart';
import '../../sales/data/sale_models.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';
import 'checkout_success.dart';
import 'customer_picker.dart';
import 'payment_sheet.dart';
import 'widgets/cart_item_tile.dart';
import 'widgets/cart_summary_section.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  Future<void> _hold(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final label = await promptText(
      context,
      title: PosStrings.holdTransactionTitle,
      label: PosStrings.holdLabelField,
      hint: PosStrings.holdLabelHint,
      confirmLabel: PosStrings.holdConfirm,
      initialValue: cart.customer?.name ?? '',
      maxLength: 60,
    );

    if (label == null) {
      return;
    }

    try {
      final taxRate = ref.read(posConfigProvider).value?.taxRate ?? 0;
      final heldOrder = await ref.read(posRepositoryProvider).holdOrder(cart: cart, total: cart.totals(taxRate).total, label: label);
      final preview = cart.items.map((i) => PosStrings.heldPreviewItem(quantity(i.quantity), i.name)).take(3).join(', ');
      ref.read(heldOrderPreviewsProvider.notifier).save(heldOrder.id, preview);
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(posConfigProvider);
      if (context.mounted) {
        showMessage(context, PosStrings.holdSuccessMessage);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(PosStrings.clearCartTitle),
        content: const Text(PosStrings.clearCartContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(PosStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(PosStrings.clearCartConfirm)),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }

  Future<void> _pay(BuildContext context) async {
    final navigator = Navigator.of(context);
    final result = await PaymentSheet.show(context);
    if (result == null || !navigator.mounted) {
      return;
    }

    // On phones the cart is its own page; close it so the success dialog lands on the catalog.
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (result is SaleDetail) {
      await CheckoutSuccess.show(navigator.context, result);
    } else if (result is QueuedSale) {
      await OfflineCheckoutSuccess.show(navigator.context, result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final config = ref.watch(posConfigProvider).value;
    final totals = cart.totals(config?.taxRate ?? 0);

    // Auto-pop on phone with slight delay when cart becomes empty (cleared, held, or deleted 1-by-1)
    ref.listen<Cart>(cartProvider, (previous, next) {
      if ((previous?.items.isNotEmpty ?? false) && next.isEmpty) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (context.mounted) {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            }
          }
        });
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s10, AppSpacing.s10, AppSpacing.s8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.slate900.withValues(alpha: 0.5)
                : AppColors.slate50,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                  onTap: () => CustomerPicker.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s7),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                          ),
                          child: Icon(
                            cart.customer == null ? AppIcons.userPlus : AppIcons.userCheck,
                            size: AppSizes.s16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSizes.s10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cart.customer?.name ?? PosStrings.defaultCustomerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                cart.customer != null ? PosStrings.memberLabel : PosStrings.chooseCustomerHint,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRight,
                          size: AppSizes.s16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!cart.isEmpty) ...[
                const SizedBox(width: AppSizes.s6),
                IconButton(
                  tooltip: PosStrings.clearCartTooltip,
                  icon: const Icon(AppIcons.trash2, size: AppSizes.s18),
                  color: AppColors.rose500,
                  onPressed: () => _clear(context, ref),
                ),
              ],
            ],
          ),
        ),
        if (!cart.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.slate950
                  : AppColors.slate100,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${cart.items.length} item • ${quantity(cart.itemCount)} pcs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.arrowLeft,
                      size: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: AppSizes.s2),
                    Text(
                      'Geser hapus',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: cart.isEmpty
              ? const EmptyState(
                  icon: AppIcons.shoppingCart,
                  title: PosStrings.emptyCartTitle,
                  description: PosStrings.emptyCartDescription,
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 68, endIndent: 14),
                  itemBuilder: (context, index) => CartItemTile(
                    item: cart.items[index],
                    canDiscount: config?.canDiscount ?? false,
                  ),
                ),
        ),
        CartSummarySection(
          cart: cart,
          config: config,
          totals: totals,
          onHold: () => _hold(context, ref),
          onPay: () => _pay(context),
        ),
      ],
    );
  }
}
