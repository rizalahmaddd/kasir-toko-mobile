import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/money_field.dart';
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
      await ref.read(posRepositoryProvider).holdOrder(cart: cart, total: cart.totals(taxRate).total, label: label);
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: Icon(cart.customer == null ? LucideIcons.userPlus : LucideIcons.user, size: 16),
                    label: Text(cart.customer?.name ?? 'Pelanggan umum', overflow: TextOverflow.ellipsis),
                    onPressed: () => CustomerPicker.show(context),
                  ),
                ),
              ),
              if (!cart.isEmpty)
                IconButton(tooltip: 'Kosongkan keranjang', icon: const Icon(LucideIcons.trash2, size: 20), onPressed: () => _clear(context, ref)),
            ],
          ),
        ),
        const Divider(),
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
                  separatorBuilder: (_, _) => const Divider(indent: 12, endIndent: 12),
                  itemBuilder: (context, index) => _CartLine(item: cart.items[index], canDiscount: config?.canDiscount ?? false),
                ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: [
              _TotalRow('Subtotal', rupiah(totals.subtotal)),
              if (config?.canDiscount ?? false)
                InkWell(
                  onTap: cart.isEmpty ? null : () => _DiscountSheet.show(context),
                  child: _TotalRow(
                    cart.discountType == DiscountType.percent ? 'Diskon ${quantity(cart.discountValue)}%' : 'Diskon',
                    totals.discountAmount > 0 ? '-${rupiah(totals.discountAmount)}' : 'Atur',
                    valueColor: totals.discountAmount > 0 ? null : theme.colorScheme.primary,
                  ),
                )
              else if (totals.discountAmount > 0)
                _TotalRow('Diskon', '-${rupiah(totals.discountAmount)}'),
              if ((config?.taxRate ?? 0) > 0) _TotalRow('${config!.taxLabel} ${quantity(config.taxRate)}%', rupiah(totals.taxAmount)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(rupiah(totals.total), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${quantity(cart.itemCount)} barang', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: cart.isEmpty ? null : () => _hold(context, ref),
                icon: const Icon(LucideIcons.pause, size: 18),
                label: const Text('Tunda'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: cart.isEmpty || config == null ? null : () => _pay(context),
                  child: Text('Bayar ${rupiah(totals.total)}'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.item, required this.canDiscount});

  final CartItem item;
  final bool canDiscount;

  void _step(BuildContext context, WidgetRef ref, double delta) {
    final warning = ref.read(cartProvider.notifier).setQuantity(item.productId, item.quantity + delta);
    if (warning != null) {
      HapticFeedback.heavyImpact();
      showMessage(context, warning, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final colors = StatusColors.of(context);

    return InkWell(
      onTap: () => _LineEditSheet.show(context, item, canDiscount: canDiscount),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${rupiah(item.price)} / ${item.unit}', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  if (item.appliedDiscount > 0)
                    Text('Diskon -${rupiah(item.appliedDiscount)}', style: theme.textTheme.bodySmall?.copyWith(color: colors.success)),
                  if (item.note != null && item.note!.isNotEmpty)
                    Text(item.note!, style: theme.textTheme.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic)),
                  if (item.exceedsStock)
                    Text('Stok tersisa ${quantity(item.stock)}', style: theme.textTheme.bodySmall?.copyWith(color: colors.warning)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(rupiah(item.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kurangi',
                      icon: Icon(item.quantity <= 1 ? LucideIcons.trash2 : LucideIcons.minus, size: 18),
                      onPressed: () => _step(context, ref, -1),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 28),
                      child: Text(quantity(item.quantity), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(tooltip: 'Tambah', icon: const Icon(LucideIcons.plus, size: 18), onPressed: () => _step(context, ref, 1)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineEditSheet extends ConsumerStatefulWidget {
  const _LineEditSheet({required this.item, required this.canDiscount});

  final CartItem item;
  final bool canDiscount;

  static Future<void> show(BuildContext context, CartItem item, {required bool canDiscount}) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _LineEditSheet(item: item, canDiscount: canDiscount),
      );

  @override
  ConsumerState<_LineEditSheet> createState() => _LineEditSheetState();
}

class _LineEditSheetState extends ConsumerState<_LineEditSheet> {
  late final _quantity = TextEditingController(text: editableQuantity(widget.item.quantity));
  late final _discount = TextEditingController(text: widget.item.discount > 0 ? thousands(widget.item.discount) : '');
  late final _note = TextEditingController(text: widget.item.note ?? '');
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _discount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final qty = parseQuantity(_quantity.text);
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Jumlah harus lebih dari 0.');
      return;
    }

    final config = ref.read(posConfigProvider).value;
    final item = widget.item;
    if (item.trackStock && !(config?.allowNegativeStock ?? false) && qty > item.stock) {
      setState(() => _error = 'Stok tersisa ${quantity(item.stock)} ${item.unit}.');
      return;
    }

    ref.read(cartProvider.notifier).updateItem(
          item.productId,
          quantity: qty,
          discount: widget.canDiscount ? parseRupiah(_discount.text) : item.discount,
          note: _note.text.trim(),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.item.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text('${rupiah(widget.item.price)} / ${widget.item.unit}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
            decoration: InputDecoration(labelText: 'Jumlah', suffixText: widget.item.unit, errorText: _error),
          ),
          if (widget.canDiscount) ...[
            const SizedBox(height: 12),
            MoneyField(controller: _discount, label: 'Diskon barang ini'),
          ],
          const SizedBox(height: 12),
          TextField(controller: _note, maxLength: 150, decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'mis. tanpa es')),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: StatusColors.of(context).danger),
                onPressed: () {
                  ref.read(cartProvider.notifier).remove(widget.item.productId);
                  Navigator.pop(context);
                },
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Hapus Barang'),
              ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Simpan')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscountSheet extends ConsumerStatefulWidget {
  const _DiscountSheet();

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _DiscountSheet());

  @override
  ConsumerState<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends ConsumerState<_DiscountSheet> {
  late DiscountType _type = ref.read(cartProvider).discountType ?? DiscountType.amount;
  late final _value = TextEditingController(text: _initialValue());
  String? _error;

  String _initialValue() {
    final cart = ref.read(cartProvider);
    if (cart.discountType == null || cart.discountValue <= 0) {
      return '';
    }
    return cart.discountType == DiscountType.percent ? editableQuantity(cart.discountValue) : thousands(cart.discountValue);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final value = _type == DiscountType.percent ? parseQuantity(_value.text) ?? 0 : parseRupiah(_value.text).toDouble();
    if (_type == DiscountType.percent && value > 100) {
      setState(() => _error = 'Diskon persen maksimal 100%.');
      return;
    }
    ref.read(cartProvider.notifier).setDiscount(_type, value);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Diskon transaksi', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<DiscountType>(
            segments: const [
              ButtonSegment(value: DiscountType.amount, label: Text('Rupiah')),
              ButtonSegment(value: DiscountType.percent, label: Text('Persen')),
            ],
            selected: {_type},
            onSelectionChanged: (selection) => setState(() {
              _type = selection.first;
              _value.clear();
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_type == DiscountType.amount)
            MoneyField(controller: _value, label: 'Potongan', autofocus: true)
          else
            TextField(
              controller: _value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
              decoration: InputDecoration(labelText: 'Potongan', suffixText: '%', errorText: _error),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).setDiscount(null, 0);
                  Navigator.pop(context);
                },
                child: const Text('Hapus Diskon'),
              ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Terapkan')),
            ],
          ),
        ],
      ),
    );
  }
}
