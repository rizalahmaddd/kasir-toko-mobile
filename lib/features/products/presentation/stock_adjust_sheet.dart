import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';

const _titles = {'stock_in': 'Stok masuk', 'stock_out': 'Stok keluar', 'opname': 'Stok opname'};

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
  bool _busy = false;
  ApiException? _error;

  bool get _isOpname => widget.type == 'opname';

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quantity = parseQuantity(_quantity.text);
    if (quantity == null) {
      setState(() => _error = ApiException(message: 'Isi jumlah dengan angka.'));
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
            unitCost: widget.type == 'stock_in' && _cost.text.isNotEmpty ? parseRupiah(_cost.text) : null,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.read(dataChangesProvider).after({DataChange.products});
      if (mounted) {
        Navigator.pop(context, true);
        showMessage(context, '${_titles[widget.type]} ${widget.product.name} dicatat.');
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
    final typed = parseQuantity(_quantity.text);
    final after = typed == null
        ? null
        : switch (widget.type) {
            'stock_in' => product.stock + typed,
            'stock_out' => product.stock - typed,
            _ => typed,
          };
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return FormSheet(
      title: _titles[widget.type]!,
      subtitle: '${product.name} · stok sekarang ${quantity(product.stock)} ${product.unit}',
      children: [
        TextField(
          controller: _quantity,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _isOpname ? 'Stok fisik hasil hitung' : 'Jumlah',
            suffixText: product.unit,
            errorText: _error?.fieldError('quantity'),
          ),
        ),
        if (after != null) ...[
          const SizedBox(height: 6),
          Text(
            'Stok setelahnya: ${quantity(after)} ${product.unit}',
            style: TextStyle(color: after < 0 ? StatusColors.of(context).danger : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
        if (widget.type == 'stock_in') ...[
          const SizedBox(height: 12),
          MoneyField(controller: _cost, label: 'Harga beli per ${product.unit} (opsional)', errorText: _error?.fieldError('unit_cost')),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 255,
          decoration: InputDecoration(
            labelText: widget.type == 'stock_out' ? 'Alasan' : 'Catatan (opsional)',
            hintText: switch (widget.type) {
              'stock_in' => 'mis. kiriman supplier',
              'stock_out' => 'mis. rusak, kedaluwarsa, dipakai sendiri',
              _ => 'mis. hitung ulang akhir bulan',
            },
            errorText: _error?.fieldError('note'),
          ),
        ),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}
