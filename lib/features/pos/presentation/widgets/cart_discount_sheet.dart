import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/money_field.dart';
import '../../cart_controller.dart';
import '../../data/pos_models.dart';

class CartDiscountSheet extends ConsumerStatefulWidget {
  const CartDiscountSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const CartDiscountSheet(),
      );

  @override
  ConsumerState<CartDiscountSheet> createState() => _CartDiscountSheetState();
}

class _CartDiscountSheetState extends ConsumerState<CartDiscountSheet> {
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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHeader(title: 'Diskon transaksi'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
    ),
  ],
),
);
}
}
