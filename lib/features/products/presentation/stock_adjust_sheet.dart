import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../data_changes.dart';
import '../../../core/constants/app_icons.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

const _titles = {
  MovementTypes.stockIn: ProductStrings.adjustTitleStockIn,
  MovementTypes.stockOut: ProductStrings.adjustTitleStockOut,
  MovementTypes.opname: ProductStrings.adjustTitleOpname,
};

class StockAdjustSheet extends ConsumerStatefulWidget {
  const StockAdjustSheet({super.key, required this.product, required this.type});

  final ProductRecord product;
  final String type;

  /// Returns true when the adjustment was saved.
  static Future<bool> show(BuildContext context, ProductRecord product, String type) async =>
      await FormSheet.show<bool>(context, StockAdjustSheet(product: product, type: type)) ?? false;

  @override
  ConsumerState<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends ConsumerState<StockAdjustSheet> {
  final _quantity = TextEditingController();
  final _cost = TextEditingController();
  final _note = TextEditingController();
  final _batchNumber = TextEditingController();
  DateTime? _expiresAt;
  int? _unitId;
  int? _batchId;
  List<ProductBatchRecord> _batches = const [];
  bool _busy = false;
  ApiException? _error;

  bool get _isOpname => widget.type == MovementTypes.opname;

  bool get _usesBatches => (ref.read(currentUserProvider)?.usesBatches ?? false) && widget.product.trackBatch;

  List<ProductUnitRecord> get _units => (ref.read(currentUserProvider)?.usesMultiUnit ?? false) && !_isOpname ? widget.product.units : const [];

  ProductUnitRecord? get _unit => _units.where((unit) => unit.id == _unitId).firstOrNull;

  @override
  void initState() {
    super.initState();
    if (_usesBatches && widget.type == MovementTypes.stockOut) {
      unawaited(ref.read(productsRepositoryProvider).batches(widget.product.id).then((batches) {
        if (mounted) {
          setState(() => _batches = batches.where((batch) => batch.quantity > 0).toList());
        }
      }, onError: (_) {}));
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _note.dispose();
    _batchNumber.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _save() async {
    final quantity = parseQuantity(_quantity.text);
    if (quantity == null) {
      setState(() => _error = ApiException(message: ProductStrings.validationQuantityNumber));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(productsRepositoryProvider).adjust(
            productId: widget.product.id,
            type: widget.type,
            quantity: quantity,
            unitCost: widget.type == MovementTypes.stockIn && _cost.text.isNotEmpty ? parseRupiah(_cost.text) : null,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            unitId: _unit?.id,
            batchNumber: _usesBatches && widget.type == MovementTypes.stockIn ? _batchNumber.text.trim() : null,
            expiresAt: _usesBatches && widget.type == MovementTypes.stockIn ? _expiresAt : null,
            batchId: _batchId,
          );
      ref.read(dataChangesProvider).after({DataChange.products});
      if (mounted) {
        Navigator.pop(context, true);
        showMessage(context, ProductStrings.stockAdjustRecordedMessage(_titles[widget.type]!, widget.product.name));
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final entered = parseQuantity(_quantity.text);
    final typed = entered == null ? null : entered * (_unit?.factor ?? 1);
    final after = typed == null
        ? null
        : switch (widget.type) {
            MovementTypes.stockIn => product.stock + typed,
            MovementTypes.stockOut => product.stock - typed,
            _ => typed,
          };
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return FormSheet(
      title: _titles[widget.type]!,
      subtitle: ProductStrings.stockAdjustSubtitle(product.name, quantity(product.stock), product.unit),
      children: [
        if (_units.isNotEmpty) ...[
          Wrap(
            spacing: AppSizes.s8,
            children: [
              ChoiceChip(label: Text(product.unit), selected: _unitId == null, onSelected: (_) => setState(() => _unitId = null)),
              for (final unit in _units)
                ChoiceChip(
                  label: Text('${unit.name} (${quantity(unit.factor)} ${product.unit})'),
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
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _isOpname ? ProductStrings.fieldPhysicalStock : ProductStrings.fieldQuantity,
            suffixText: _unit?.name ?? product.unit,
            errorText: _error?.fieldError('quantity'),
          ),
        ),
        if (after != null) ...[
          const SizedBox(height: AppSizes.s6),
          Text(
            ProductStrings.stockAfterLabel(quantity(after), product.unit),
            style: TextStyle(color: after < 0 ? StatusColors.of(context).danger : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
        if (widget.type == MovementTypes.stockIn) ...[
          const SizedBox(height: AppSizes.s12),
          MoneyField(controller: _cost, label: ProductStrings.unitCostField(_unit?.name ?? product.unit), errorText: _error?.fieldError('unit_cost')),
        ],
        if (_usesBatches && widget.type == MovementTypes.stockIn) ...[
          const SizedBox(height: AppSizes.s12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _batchNumber,
                  decoration: InputDecoration(labelText: BusinessStrings.batchNumberRequired, errorText: _error?.fieldError('batch_number')),
                ),
              ),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(AppIcons.calendar, size: AppSizes.s16),
                  label: Text(_expiresAt == null ? BusinessStrings.expiresAt : dateOnly(_expiresAt!)),
                ),
              ),
            ],
          ),
        ],
        if (_usesBatches && widget.type == MovementTypes.stockOut && _batches.isNotEmpty) ...[
          const SizedBox(height: AppSizes.s12),
          DropdownButtonFormField<int?>(
            initialValue: _batchId,
            decoration: const InputDecoration(labelText: BusinessStrings.pickBatch),
            items: [
              const DropdownMenuItem(value: null, child: Text(BusinessStrings.pickBatchAuto)),
              for (final batch in _batches)
                DropdownMenuItem(
                  value: batch.id,
                  child: Text(
                    '${batch.batchNumber ?? BusinessStrings.noBatchNumber}${batch.expiresAt == null ? '' : ' · ${dateOnly(batch.expiresAt!)}'} · ${quantity(batch.quantity)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _batchId = value),
          ),
        ],
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _note,
          maxLength: 255,
          decoration: InputDecoration(
            labelText: widget.type == MovementTypes.stockOut ? ProductStrings.fieldReason : ProductStrings.fieldNoteOptional,
            hintText: switch (widget.type) {
              MovementTypes.stockIn => ProductStrings.hintAdjustStockIn,
              MovementTypes.stockOut => ProductStrings.hintAdjustStockOut,
              _ => ProductStrings.hintAdjustOpname,
            },
            errorText: _error?.fieldError('note'),
          ),
        ),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: AppSizes.s8),
        FilledButton(onPressed: _busy ? null : _save, child: const Text(ProductStrings.labelSave)),
      ],
    );
  }
}
