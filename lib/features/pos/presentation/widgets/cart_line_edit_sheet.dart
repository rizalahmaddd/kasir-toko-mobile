import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/money_field.dart';
import '../../cart_controller.dart';
import '../../data/pos_models.dart';
import '../../pos_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class CartLineEditSheet extends ConsumerStatefulWidget {
  const CartLineEditSheet({super.key, required this.item, required this.canDiscount});

  final CartItem item;
  final bool canDiscount;

  static Future<void> show(BuildContext context, CartItem item, {required bool canDiscount}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CartLineEditSheet(item: item, canDiscount: canDiscount),
      );

  @override
  ConsumerState<CartLineEditSheet> createState() => _CartLineEditSheetState();
}

class _CartLineEditSheetState extends ConsumerState<CartLineEditSheet> {
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
      setState(() => _error = PosStrings.errQuantityPositive);
      return;
    }

    final config = ref.read(posConfigProvider).value;
    final item = widget.item;
    if (item.trackStock && !(config?.allowNegativeStock ?? false) && qty > item.stock) {
      setState(() => _error = PosStrings.stockRemainingWithUnit(quantity(item.stock), item.unit));
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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(
            title: widget.item.name,
            subtitle: PosStrings.pricePerUnit(rupiah(widget.item.price), widget.item.unit),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s0, AppSpacing.s20, AppSpacing.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
            decoration: InputDecoration(labelText: PosStrings.quantityFieldLabel, suffixText: widget.item.unit, errorText: _error),
          ),
          if (widget.canDiscount) ...[
            const SizedBox(height: AppSizes.s12),
            MoneyField(controller: _discount, label: PosStrings.itemDiscountLabel),
          ],
          const SizedBox(height: AppSizes.s12),
          TextField(
            controller: _note,
            maxLength: 150,
            decoration: const InputDecoration(labelText: PosStrings.noteFieldLabel, hintText: PosStrings.noteFieldHint),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: StatusColors.of(context).danger,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                  ),
                  onPressed: () {
                    ref.read(cartProvider.notifier).remove(widget.item.productId);
                    Navigator.pop(context);
                  },
                  icon: const Icon(AppIcons.trash2, size: AppSizes.s18),
                  label: const Text(PosStrings.deleteItemButton, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: AppSizes.s8),
              FilledButton(onPressed: _save, child: const Text(PosStrings.save)),
            ],
          ),
        ],
      ),
    ),
  ],
),
);
}
}
