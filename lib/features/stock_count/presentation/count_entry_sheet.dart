import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
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
  int? outletId,
  required CountCatalogItem item,
  List<CountBatch> batches = const [],
  double? countedQty,
  double? systemQty,
}) =>
    FormSheet.show<QueuedCount>(
      context,
      _CountEntrySheet(countId: countId, userId: userId, outletId: outletId, item: item, batches: batches, countedQty: countedQty, systemQty: systemQty),
    );

class _CountEntrySheet extends StatefulWidget {
  const _CountEntrySheet({
    required this.countId,
    required this.userId,
    this.outletId,
    required this.item,
    required this.batches,
    this.countedQty,
    this.systemQty,
  });

  final int countId;
  final int userId;
  final int? outletId;
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

  double _calculateCurrentTotal() {
    final lines = <int?, double>{};
    for (final MapEntry(key: unitId, value: field) in _fields.entries) {
      if (field.text.trim().isEmpty) continue;
      final val = parseQuantity(field.text);
      if (val != null && val >= 0) {
        lines[unitId] = val;
      }
    }
    return baseQuantity(lines, widget.item.units);
  }

  void _stepQuantity(int? unitId, double delta) {
    final field = _fields[unitId]!;
    final current = parseQuantity(field.text) ?? 0;
    final next = (current + delta).clamp(0, 999999).toDouble();
    field.text = next == 0 ? '' : (next % 1 == 0 ? next.toInt().toString() : next.toString());
    setState(() {});
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
        outletId: widget.outletId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTotal = _calculateCurrentTotal();

    return FormSheet(
      title: item.name,
      subtitle: StockCountStrings.entryHint(quantity(widget.countedQty ?? 0), item.unit),
      children: [
        for (final unitId in [null, ...item.units.map((u) => u.id)])
          Builder(builder: (context) {
            final isBase = unitId == null;
            final unitName = isBase ? item.unit : item.units.firstWhere((u) => u.id == unitId).name;
            final factor = isBase ? 1.0 : item.units.firstWhere((u) => u.id == unitId).factor;
            final conversionSubtitle = isBase ? StockCountStrings.baseUnit : '1 $unitName = ${quantity(factor)} ${item.unit}';

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s8),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.r10),
                border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unitName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: AppSizes.s2),
                        Text(
                          conversionSubtitle,
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(AppIcons.minus, size: AppSizes.s16),
                        onPressed: () => _stepQuantity(unitId, -1),
                      ),
                      const SizedBox(width: AppSizes.s6),
                      SizedBox(
                        width: 76,
                        child: TextField(
                          controller: _fields[unitId],
                          autofocus: isBase,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s8),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _save(),
                        ),
                      ),
                      const SizedBox(width: AppSizes.s6),
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(AppIcons.plus, size: AppSizes.s16),
                        onPressed: () => _stepQuantity(unitId, 1),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

        if (currentTotal > 0 && item.units.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.s4, bottom: AppSpacing.s8),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.r8),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(AppIcons.calculator, size: AppSizes.s18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSizes.s10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: StockCountStrings.entryTotal,
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: '${quantity(currentTotal)} ${item.unit}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (item.trackBatch) ...[
          const SizedBox(height: AppSizes.s12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(AppRadius.r10),
              border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.package, size: AppSizes.s16, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSizes.s8),
                    Text(StockCountStrings.batch, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSizes.s10),
                DropdownButtonFormField<int?>(
                  initialValue: _batchId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: StockCountStrings.batch, isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text(StockCountStrings.noBatch)),
                    for (final batch in widget.batches)
                      DropdownMenuItem(
                        value: batch.id,
                        child: Text([batch.label, if (batch.expired) StockCountStrings.expired].join(' · ')),
                      ),
                    const DropdownMenuItem(value: _newBatch, child: Text(StockCountStrings.newBatch)),
                  ],
                  onChanged: (value) => setState(() => _batchId = value),
                ),
                if (_batchId == _newBatch) ...[
                  const SizedBox(height: AppSizes.s10),
                  TextField(
                    controller: _batchNumber,
                    decoration: const InputDecoration(labelText: StockCountStrings.newBatchNumber, isDense: true),
                  ),
                  const SizedBox(height: AppSizes.s10),
                  TextField(
                    controller: _batchExpiry,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: StockCountStrings.newBatchExpiry,
                      suffixIcon: Icon(AppIcons.calendar, size: AppSizes.s18),
                      isDense: true,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: DateTime.now(),
                      );
                      if (picked != null) {
                        _batchExpiry.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: StockCountStrings.note,
            hintText: StockCountStrings.noteHint,
            prefixIcon: Icon(AppIcons.fileText, size: AppSizes.s18),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: AppSizes.s16),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(AppIcons.check, size: AppSizes.s18),
          label: const Text(StockCountStrings.saveEntry),
        ),
      ],
    );
  }
}
