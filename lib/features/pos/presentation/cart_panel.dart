import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../offline/offline_queue.dart';
import '../../offline/presentation/offline_checkout_success.dart';
import '../../sales/data/sale_models.dart';
import '../cart_controller.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';
import 'checkout_success.dart';
import 'customer_picker.dart';
import 'payment_sheet.dart';
import 'widgets/cart_item_tile.dart';
import 'widgets/cart_summary_section.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  Future<void> _hold(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final label = await promptText(
      context,
      title: 'Tunda transaksi',
      label: 'Nama penanda (opsional)',
      hint: 'mis. Bu Rina, meja 3',
      confirmLabel: 'Tunda',
      initialValue: cart.customer?.name ?? '',
      maxLength: 60,
    );

    if (label == null) {
      return;
    }

    try {
      final taxRate = ref.read(posConfigProvider).value?.taxRate ?? 0;
      final heldOrder = await ref.read(posRepositoryProvider).holdOrder(cart: cart, total: cart.totals(taxRate).total, label: label);
      final preview = cart.items.map((i) => '${quantity(i.quantity)}x ${i.name}').take(3).join(', ');
      ref.read(heldOrderPreviewsProvider.notifier).save(heldOrder.id, preview);
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(posConfigProvider);
      if (context.mounted) {
        showMessage(context, 'Transaksi ditunda. Buka lagi dari tombol jam di atas katalog.');
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
        title: const Text('Kosongkan keranjang?'),
        content: const Text('Semua barang di keranjang akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kosongkan')),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
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
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => CustomerPicker.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            cart.customer == null ? LucideIcons.userPlus : LucideIcons.userCheck,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cart.customer?.name ?? 'Pelanggan umum',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                cart.customer != null ? 'Member / Pelanggan' : 'Pilih member atau kasbon',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!cart.isEmpty) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Kosongkan keranjang',
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  color: AppColors.rose500,
                  onPressed: () => _clear(context, ref),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.shoppingCart,
                  title: 'Keranjang kosong',
                  description: 'Ketuk produk atau scan barcode untuk menambahkan barang.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 14, endIndent: 14),
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
