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
import '../pos_actions.dart';
import 'modifier_picker_sheet.dart';

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
  late int? _unitId = widget.item.unitId;
  String? _error;

  ProductUnitOption? get _unit => widget.item.units.where((unit) => unit.id == _unitId).firstOrNull;

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

    final item = widget.item;
    final cart = ref.read(cartProvider.notifier);
    final problem = cart.stockProblem(item, qty, _unit?.factor ?? 1);
    if (problem != null) {
      setState(() => _error = PosStrings.stockRemainingWithUnit(quantity(item.stock), item.baseUnit ?? item.unit));
      return;
    }

    cart.updateItem(
      item.key,
      quantity: qty,
      discount: widget.canDiscount ? parseRupiah(_discount.text) : item.discount,
      note: _note.text.trim(),
      unit: _unit,
      changeUnit: _unitId != item.unitId,
    );
    Navigator.pop(context);
  }

  Future<void> _editModifiers() async {
    final item = widget.item;
    final cart = ref.read(cartProvider.notifier);
    final picked = await ModifierPickerSheet.show(
      context,
      title: item.name,
      groups: item.modifierGroups,
      selected: item.modifiers,
      confirmLabel: PosStrings.modifierSave,
    );
    if (picked != null && mounted) {
      cart.setModifiers(item.key, picked);
      Navigator.pop(context);
    }
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
                if (widget.item.trackSerial) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.serials.isEmpty ? PosStrings.serialPick : 'SN: ${widget.item.serials.join(', ')}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final sheetContext = context;
                          await editLineSerials(sheetContext, ref, widget.item);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        child: const Text(PosStrings.serialPick),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s12),
                ],
                if (widget.item.modifierGroups.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(PosStrings.modifierSectionLabel, style: Theme.of(context).textTheme.labelMedium),
                            Text(
                              widget.item.modifiers.isEmpty ? PosStrings.modifierNone : widget.item.modifierNames,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(onPressed: _editModifiers, child: const Text(PosStrings.modifierEdit)),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s12),
                ],
                if (widget.item.units.isNotEmpty) ...[
                  Text(PosStrings.unitLabel, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: AppSizes.s6),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      ChoiceChip(
                        label: Text('${widget.item.baseUnit ?? widget.item.unit} · ${rupiah(widget.item.basePrice ?? widget.item.price)}'),
                        selected: _unitId == null,
                        onSelected: (_) => setState(() => _unitId = null),
                      ),
                      for (final unit in widget.item.units)
                        ChoiceChip(
                          label: Text(PosStrings.unitOption(unit.name, quantity(unit.factor), widget.item.baseUnit ?? '', rupiah(unit.price))),
                          selected: _unitId == unit.id,
                          onSelected: (_) => setState(() => _unitId = unit.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s12),
                ],
                TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
            decoration: InputDecoration(labelText: PosStrings.quantityFieldLabel, suffixText: _unit?.name ?? widget.item.baseUnit ?? widget.item.unit, errorText: _error),
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
                    ref.read(cartProvider.notifier).remove(widget.item.key);
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
