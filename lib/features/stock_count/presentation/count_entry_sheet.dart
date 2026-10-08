import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../count_queue.dart';
import '../data/stock_count_models.dart';
import '../stock_count_providers.dart';

const _newBatch = -1;

/// Isi hitungan satu barang per satuan (mis. 2 dus + 5 pak + 3 pcs), plus batch untuk produk ber-batch.
/// Mengembalikan entri siap masuk antrean, atau null bila dibatalkan.
Future<QueuedCount?> showCountEntrySheet(
  BuildContext context, {
  required int countId,
  required int userId,
  required CountCatalogItem item,
  List<CountBatch> batches = const [],
  double? countedQty,
  double? systemQty,
}) =>
    FormSheet.show<QueuedCount>(
      context,
      _CountEntrySheet(countId: countId, userId: userId, item: item, batches: batches, countedQty: countedQty, systemQty: systemQty),
    );

class _CountEntrySheet extends StatefulWidget {
  const _CountEntrySheet({required this.countId, required this.userId, required this.item, required this.batches, this.countedQty, this.systemQty});

  final int countId;
  final int userId;
  final CountCatalogItem item;
  final List<CountBatch> batches;
  final double? countedQty;

  /// Stok sistem, hanya bila penghitung boleh melihatnya; dipakai untuk menahan salah ketik besar.
  final double? systemQty;

  @override
  State<_CountEntrySheet> createState() => _CountEntrySheetState();
}

class _CountEntrySheetState extends State<_CountEntrySheet> {
  late final Map<int?, TextEditingController> _fields = {
    null: TextEditingController(),
    for (final unit in widget.item.units) unit.id: TextEditingController(),
  };
  final _note = TextEditingController();
  final _batchNumber = TextEditingController();
  final _batchExpiry = TextEditingController();
  int? _batchId;
  String? _error;

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _note.dispose();
    _batchNumber.dispose();
    _batchExpiry.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lines = <int?, double>{};
    for (final MapEntry(key: unitId, value: field) in _fields.entries) {
      if (field.text.trim().isEmpty) {
        continue;
      }
      final value = parseQuantity(field.text);
      if (value == null || value < 0) {
        setState(() => _error = StockCountStrings.errQuantity);
        return;
      }
      lines[unitId] = value;
    }
    if (lines.isEmpty) {
      setState(() => _error = StockCountStrings.errQuantity);
      return;
    }
    if (_batchId == _newBatch && _batchNumber.text.trim().isEmpty) {
      setState(() => _error = StockCountStrings.errBatchNumber);
      return;
    }
    final system = widget.systemQty ?? 0;
    if (system > 0 && baseQuantity(lines, widget.item.units) > system * 10) {
      final ok = await confirmAction(
        context,
        title: StockCountStrings.largeCountTitle,
        message: StockCountStrings.largeCountMessage('${quantity(system)} ${widget.item.unit}'),
        confirmLabel: StockCountStrings.largeCountConfirm,
      );
      if (!ok || !mounted) {
        return;
      }
    }

    Navigator.pop(
      context,
      countEntry(
        countId: widget.countId,
        userId: widget.userId,
        item: widget.item,
        lines: lines,
        batchId: _batchId == _newBatch ? null : _batchId,
        newBatchNumber: _batchId == _newBatch ? _batchNumber.text : null,
        newBatchExpiry: _batchId == _newBatch && _batchExpiry.text.trim().isNotEmpty ? _batchExpiry.text.trim() : null,
        note: _note.text,
      ),
    );
  }

  Widget _quantityField(String label, TextEditingController controller, {bool autofocus = false}) => TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: label, hintText: '0'),
        textAlign: TextAlign.end,
        onSubmitted: (_) => _save(),
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return FormSheet(
      title: item.name,
      subtitle: StockCountStrings.entryHint(quantity(widget.countedQty ?? 0), item.unit),
      children: [
        Wrap(
          spacing: AppSizes.s12,
          runSpacing: AppSizes.s12,
          children: [
            SizedBox(width: 140, child: _quantityField(item.unit, _fields[null]!, autofocus: true)),
            for (final unit in item.units) SizedBox(width: 140, child: _quantityField('${unit.name} (${quantity(unit.factor)})', _fields[unit.id]!)),
          ],
        ),
        if (item.trackBatch) ...[
          const SizedBox(height: AppSizes.s16),
          DropdownButtonFormField<int?>(
            initialValue: _batchId,
            decoration: const InputDecoration(labelText: StockCountStrings.batch),
            items: [
              const DropdownMenuItem(value: null, child: Text(StockCountStrings.noBatch)),
              for (final batch in widget.batches)
                DropdownMenuItem(value: batch.id, child: Text([batch.label, if (batch.expired) StockCountStrings.expired].join(' · '))),
              const DropdownMenuItem(value: _newBatch, child: Text(StockCountStrings.newBatch)),
            ],
            onChanged: (value) => setState(() => _batchId = value),
          ),
          if (_batchId == _newBatch) ...[
            const SizedBox(height: AppSizes.s8),
            TextField(controller: _batchNumber, decoration: const InputDecoration(labelText: StockCountStrings.newBatchNumber)),
            const SizedBox(height: AppSizes.s8),
            TextField(
              controller: _batchExpiry,
              readOnly: true,
              decoration: const InputDecoration(labelText: StockCountStrings.newBatchExpiry),
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: DateTime.now());
                if (picked != null) {
                  _batchExpiry.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                }
              },
            ),
          ],
        ],
        const SizedBox(height: AppSizes.s12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: StockCountStrings.note, hintText: StockCountStrings.noteHint)),
        if (_error != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: AppSizes.s16),
        FilledButton(onPressed: _save, child: const Text(StockCountStrings.saveEntry)),
      ],
    );
  }
}
