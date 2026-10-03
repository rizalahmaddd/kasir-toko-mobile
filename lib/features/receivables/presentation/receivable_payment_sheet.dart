import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../pos/presentation/widgets/qris_view.dart';
import '../../sales/data/sale_models.dart';
import '../receivables.dart';
import 'payment_history_sheet.dart';

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
  bool _showQris = false;
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
      ref.read(dataChangesProvider).after({DataChange.sales});
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final generalError = _error != null && _error!.fieldError('amount') == null && _error!.fieldError('reference') == null ? _error!.message : null;
    final currentAmount = parseRupiah(_amount.text);

    return FormSheet(
      title: 'Catat pelunasan',
      subtitle: '${widget.number}${widget.customerName == null ? '' : ' · ${widget.customerName}'} · sisa ${rupiah(widget.due)}',
      children: [
        // Button to view payment history
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(LucideIcons.history, size: 16),
          label: const Text('Lihat Riwayat Pembayaran Sebelumnya', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          onPressed: () => PaymentHistorySheet.show(
            context,
            saleId: widget.saleId,
            number: widget.number,
            customerName: widget.customerName,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in _methods)
              ChoiceChip(
                label: Text(label),
                selected: _method == value,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _method = value;
                  if (_method != 'qris') _showQris = false;
                }),
              ),
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
        if (_method == 'qris') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(_showQris ? LucideIcons.chevronUp : LucideIcons.qrCode, size: 18),
            label: Text(
              _showQris
                  ? 'Sembunyikan QRIS Dinamis'
                  : 'Tampilkan QRIS Dinamis (${currentAmount > 0 ? rupiah(currentAmount) : 'Sesuai Nominal'})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              if (currentAmount <= 0 && !_showQris) {
                showMessage(context, 'Isi nominal pembayaran terlebih dahulu.');
                return;
              }
              setState(() => _showQris = !_showQris);
            },
          ),
          if (_showQris && currentAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: QrisPaymentView(amount: currentAmount),
            ),
          ],
        ],
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
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
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
