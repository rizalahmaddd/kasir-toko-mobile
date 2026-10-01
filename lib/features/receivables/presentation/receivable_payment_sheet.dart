import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../customers/customers_providers.dart';
import '../../shift/shift_controller.dart';
import '../../sales/data/sale_models.dart';
import '../../sales/sales_controller.dart';
import '../receivables.dart';

const _methods = [('cash', 'Tunai'), ('qris', 'QRIS'), ('transfer', 'Transfer'), ('card', 'Kartu')];

class ReceivablePaymentSheet extends ConsumerStatefulWidget {
  const ReceivablePaymentSheet({super.key, required this.saleId, required this.number, required this.due, this.customerName});

  final int saleId;
  final String number;
  final int due;
  final String? customerName;

  /// Returns the updated sale when a payment was recorded.
  static Future<SaleDetail?> show(BuildContext context, {required int saleId, required String number, required int due, String? customerName}) =>
      FormSheet.show<SaleDetail>(context, ReceivablePaymentSheet(saleId: saleId, number: number, due: due, customerName: customerName));

  @override
  ConsumerState<ReceivablePaymentSheet> createState() => _ReceivablePaymentSheetState();
}

class _ReceivablePaymentSheetState extends ConsumerState<ReceivablePaymentSheet> {
  late final _amount = TextEditingController(text: thousands(widget.due));
  final _reference = TextEditingController();
  String _method = 'cash';
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final sale = await ref.read(receivablesRepositoryProvider).pay(
            widget.saleId,
            amount: parseRupiah(_amount.text),
            method: _method,
            reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          );
      ref
        ..invalidate(receivablesProvider)
        ..invalidate(saleDetailProvider(widget.saleId))
        ..invalidate(salesProvider)
        ..invalidate(currentShiftProvider)
        ..invalidate(customerReceivablesProvider)
        ..invalidate(customerSalesProvider);
      if (mounted) {
        Navigator.pop(context, sale);
        showMessage(context, sale.dueAmount == 0 ? 'Kasbon ${sale.number} lunas.' : 'Pelunasan dicatat. Sisa ${rupiah(sale.dueAmount)}.');
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
    final generalError = _error != null && _error!.fieldError('amount') == null && _error!.fieldError('reference') == null ? _error!.message : null;

    return FormSheet(
      title: 'Catat pelunasan',
      subtitle: '${widget.number}${widget.customerName == null ? '' : ' · ${widget.customerName}'} · sisa ${rupiah(widget.due)}',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in _methods)
              ChoiceChip(label: Text(label), selected: _method == value, showCheckmark: false, onSelected: (_) => setState(() => _method = value)),
          ],
        ),
        const SizedBox(height: 12),
        MoneyField(controller: _amount, label: 'Nominal dibayar', errorText: _error?.fieldError('amount'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(label: const Text('Lunas'), onPressed: () => setState(() => _amount.text = thousands(widget.due))),
            if (widget.due >= 2) ActionChip(label: const Text('Setengah'), onPressed: () => setState(() => _amount.text = thousands(widget.due ~/ 2))),
          ],
        ),
        if (_method != 'cash') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            maxLength: 100,
            decoration: InputDecoration(labelText: 'No. referensi (opsional)', errorText: _error?.fieldError('reference')),
          ),
        ],
        if (_method == 'cash')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pelunasan tunai masuk ke rekap laci shift yang sedang buka.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        if (generalError != null) ...[
          const SizedBox(height: 8),
          Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Simpan Pelunasan')),
      ],
    );
  }
}
