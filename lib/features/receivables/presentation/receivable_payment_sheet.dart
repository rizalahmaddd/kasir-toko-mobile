import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

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
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

const _methods = [(PaymentMethods.cash, ReceivableStrings.methodCash), (PaymentMethods.qris, ReceivableStrings.methodQris), (PaymentMethods.transfer, ReceivableStrings.methodTransfer), (PaymentMethods.card, ReceivableStrings.methodCard)];

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
  String _method = PaymentMethods.cash;
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
        showMessage(context, sale.dueAmount == 0 ? ReceivableStrings.creditPaidOff(sale.number) : ReceivableStrings.paymentRecorded(rupiah(sale.dueAmount)));
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
      title: ReceivableStrings.recordPaymentTitle,
      subtitle: ReceivableStrings.paymentSheetSubtitle(widget.number, widget.customerName, rupiah(widget.due)),
      children: [
        // Button to view payment history
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
          ),
          icon: const Icon(AppIcons.history, size: AppSizes.s16),
          label: const Text(ReceivableStrings.viewPriorPayments, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          onPressed: () => PaymentHistorySheet.show(
            context,
            saleId: widget.saleId,
            number: widget.number,
            customerName: widget.customerName,
          ),
        ),
        const SizedBox(height: AppSizes.s12),
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
                  if (_method != PaymentMethods.qris) _showQris = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.s12),
        MoneyField(controller: _amount, label: ReceivableStrings.amountPaidLabel, errorText: _error?.fieldError('amount'), onChanged: (_) => setState(() {})),
        const SizedBox(height: AppSizes.s6),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(label: const Text(ReceivableStrings.paidOff), onPressed: () => setState(() => _amount.text = thousands(widget.due))),
            if (widget.due >= 2) ActionChip(label: const Text(ReceivableStrings.half), onPressed: () => setState(() => _amount.text = thousands(widget.due ~/ 2))),
          ],
        ),
        if (_method == PaymentMethods.qris) ...[
          const SizedBox(height: AppSizes.s12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
            ),
            icon: Icon(_showQris ? AppIcons.chevronUp : AppIcons.qrCode, size: AppSizes.s18),
            label: Text(
              _showQris
                  ? ReceivableStrings.hideDynamicQris
                  : ReceivableStrings.showDynamicQris(currentAmount > 0 ? rupiah(currentAmount) : ReceivableStrings.qrisAmountPlaceholder),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              if (currentAmount <= 0 && !_showQris) {
                showMessage(context, ReceivableStrings.amountRequired);
                return;
              }
              setState(() => _showQris = !_showQris);
            },
          ),
          if (_showQris && currentAmount > 0) ...[
            const SizedBox(height: AppSizes.s12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : AppColors.slate50,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: QrisPaymentView(amount: currentAmount),
            ),
          ],
        ],
        if (_method != PaymentMethods.cash) ...[
          const SizedBox(height: AppSizes.s12),
          TextField(
            controller: _reference,
            maxLength: 100,
            decoration: InputDecoration(labelText: ReceivableStrings.referenceLabel, errorText: _error?.fieldError('reference')),
          ),
        ],
        if (_method == PaymentMethods.cash)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Text(
              ReceivableStrings.cashPaymentNote,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        if (generalError != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        ],
        const SizedBox(height: AppSizes.s16),
        FilledButton(onPressed: _busy ? null : _save, child: const Text(ReceivableStrings.savePayment)),
      ],
    );
  }
}
