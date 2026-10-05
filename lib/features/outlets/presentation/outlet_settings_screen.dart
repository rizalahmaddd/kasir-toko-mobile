import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../data/outlet_models.dart';
import '../data/outlet_repository.dart';
import '../outlet_controller.dart';

/// Tax, payment methods, receipt and QRIS of one outlet. Each section either follows the shop
/// setting or carries values of its own.
class OutletSettingsScreen extends ConsumerWidget {
  const OutletSettingsScreen({super.key, required this.outletId});

  final int outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentUserProvider)?.outletById(outletId)?.name ?? ref.watch(managedOutletsProvider).value?.where((o) => o.id == outletId).firstOrNull?.name ?? '';
    final settings = ref.watch(outletSettingsProvider(outletId));

    return Scaffold(
      appBar: AppBar(title: Text(OutletStrings.settingsTitle(name))),
      body: AsyncView(
        value: settings,
        onRetry: () => ref.invalidate(outletSettingsProvider(outletId)),
        data: (data) => _SettingsForm(outletId: outletId, initial: data),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.outletId, required this.initial});

  final int outletId;
  final OutletSettingsData initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  static const _methods = [
    (PaymentMethods.qris, CoreStrings.paymentQris),
    (PaymentMethods.transfer, CoreStrings.paymentTransfer),
    (PaymentMethods.card, CoreStrings.paymentCard),
  ];

  late bool _taxInherit = widget.initial.taxInherit;
  late bool _taxEnabled = widget.initial.taxEnabled;
  late final _taxRate = TextEditingController(text: widget.initial.taxRate);
  late final _taxLabel = TextEditingController(text: widget.initial.taxLabel);
  late bool _paymentsInherit = widget.initial.paymentsInherit;
  late final Set<String> _payments = {...widget.initial.paymentMethods};
  late bool _receiptInherit = widget.initial.receiptInherit;
  late String _width = widget.initial.receiptWidth;
  late final _header = TextEditingController(text: widget.initial.receiptHeader);
  late final _footer = TextEditingController(text: widget.initial.receiptFooter);
  late bool _autoPrint = widget.initial.autoPrint;
  late bool _qrisInherit = widget.initial.qrisInherit;
  late final _qris = TextEditingController(text: widget.initial.qrisPayload);
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _taxRate.dispose();
    _taxLabel.dispose();
    _header.dispose();
    _footer.dispose();
    _qris.dispose();
    super.dispose();
  }

  OutletSettingsData get _data => OutletSettingsData(
        taxInherit: _taxInherit,
        taxEnabled: _taxEnabled,
        taxRate: _taxRate.text.trim().replaceAll(',', '.'),
        taxLabel: _taxLabel.text.trim(),
        paymentsInherit: _paymentsInherit,
        paymentMethods: [PaymentMethods.cash, ..._payments.where((method) => method != PaymentMethods.cash)],
        receiptInherit: _receiptInherit,
        receiptWidth: _width,
        receiptHeader: _header.text.trim(),
        receiptFooter: _footer.text.trim(),
        autoPrint: _autoPrint,
        qrisInherit: _qrisInherit,
        qrisPayload: _qris.text.trim(),
      );

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(outletRepositoryProvider).saveSettings(widget.outletId, _data);
      ref.invalidate(outletSettingsProvider(widget.outletId));
      if (mounted) {
        showMessage(context, OutletStrings.settingsSaved);
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _section(List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
        child: Padding(padding: const EdgeInsets.all(AppSpacing.s12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
      );

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        const Text(OutletStrings.settingsHelp, style: TextStyle(fontSize: 12.5)),
        const SizedBox(height: AppSizes.s12),
        _section([
          AppSwitchListTile(title: const Text(OutletStrings.inheritTax), value: _taxInherit, onChanged: (value) => setState(() => _taxInherit = value)),
          if (!_taxInherit) ...[
            AppSwitchListTile(title: const Text(OutletStrings.taxEnabled), value: _taxEnabled, onChanged: (value) => setState(() => _taxEnabled = value)),
            if (_taxEnabled)
              Row(
                children: [
                  Expanded(child: TextField(controller: _taxLabel, decoration: InputDecoration(labelText: OutletStrings.taxLabelField, errorText: _error?.fieldError('tax.label')))),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: TextField(
                      controller: _taxRate,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: OutletStrings.taxRateField, errorText: _error?.fieldError('tax.rate')),
                    ),
                  ),
                ],
              ),
          ],
        ]),
        _section([
          AppSwitchListTile(title: const Text(OutletStrings.inheritPayments), value: _paymentsInherit, onChanged: (value) => setState(() => _paymentsInherit = value)),
          if (!_paymentsInherit) ...[
            for (final (value, label) in _methods)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(label),
                value: _payments.contains(value),
                onChanged: (checked) => setState(() => checked == true ? _payments.add(value) : _payments.remove(value)),
              ),
            const Text(OutletStrings.paymentsHelp, style: TextStyle(fontSize: 12)),
          ],
        ]),
        _section([
          AppSwitchListTile(title: const Text(OutletStrings.inheritReceipt), value: _receiptInherit, onChanged: (value) => setState(() => _receiptInherit = value)),
          if (!_receiptInherit) ...[
            DropdownButtonFormField<String>(
              initialValue: _width,
              decoration: const InputDecoration(labelText: OutletStrings.receiptWidth),
              items: const [DropdownMenuItem(value: '58', child: Text('58 mm')), DropdownMenuItem(value: '80', child: Text('80 mm'))],
              onChanged: (value) => setState(() => _width = value ?? '58'),
            ),
            const SizedBox(height: AppSizes.s12),
            TextField(controller: _header, maxLines: 2, decoration: InputDecoration(labelText: OutletStrings.receiptHeader, errorText: _error?.fieldError('receipt.header'))),
            const SizedBox(height: AppSizes.s12),
            TextField(controller: _footer, maxLines: 2, decoration: InputDecoration(labelText: OutletStrings.receiptFooter, errorText: _error?.fieldError('receipt.footer'))),
            AppSwitchListTile(title: const Text(OutletStrings.autoPrint), value: _autoPrint, onChanged: (value) => setState(() => _autoPrint = value)),
          ],
        ]),
        _section([
          AppSwitchListTile(title: const Text(OutletStrings.inheritQris), value: _qrisInherit, onChanged: (value) => setState(() => _qrisInherit = value)),
          if (!_qrisInherit)
            TextField(
              controller: _qris,
              maxLines: 3,
              decoration: InputDecoration(labelText: OutletStrings.qrisPayload, helperText: OutletStrings.qrisHelp, errorText: _error?.fieldError('qris.payload')),
            ),
        ]),
        if (generalError != null) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s8), child: Text(generalError, style: TextStyle(color: StatusColors.of(context).danger))),
        FilledButton(onPressed: _busy ? null : _save, child: const Text(OutletStrings.save)),
      ],
    );
  }
}
