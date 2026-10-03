import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/state_views.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

typedef RecordCash = Future<void> Function({required String type, required int amount, required String reason});

class CashMovementSheet extends StatefulWidget {
  const CashMovementSheet({super.key, required this.type, required this.recordCash});

  final String type;
  final RecordCash recordCash;

  @override
  State<CashMovementSheet> createState() => _CashMovementSheetState();
}

class _CashMovementSheetState extends State<CashMovementSheet> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  bool get _isIn => widget.type == CashMovementTypes.cashIn;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.recordCash(type: widget.type, amount: parseRupiah(_amount.text), reason: _reason.text.trim());
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, _isIn ? ShiftStrings.cashInRecorded : ShiftStrings.cashOutRecorded);
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
    final generalError = _error != null && _error!.fieldError('amount') == null && _error!.fieldError('reason') == null ? _error!.message : null;

    return FormSheet(
      title: _isIn ? ShiftStrings.recordCashInTitle : ShiftStrings.recordCashOutTitle,
      children: [
        MoneyField(controller: _amount, label: ShiftStrings.amountLabel, autofocus: true, errorText: _error?.fieldError('amount')),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _reason,
          maxLength: 150,
          decoration: InputDecoration(
            labelText: ShiftStrings.reasonLabel,
            hintText: _isIn ? ShiftStrings.cashInReasonHint : ShiftStrings.cashOutReasonHint,
            errorText: _error?.fieldError('reason'),
          ),
        ),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: AppSizes.s8),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_isIn ? ShiftStrings.saveCashInButton : ShiftStrings.saveCashOutButton)),
      ],
    );
  }
}
