import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/shift_models.dart';

typedef CloseShift = Future<Shift> Function({required int countedCash, String? note});

class CloseShiftSheet extends StatefulWidget {
  const CloseShiftSheet({super.key, required this.shift, required this.close});

  final Shift shift;
  final CloseShift close;

  @override
  State<CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<CloseShiftSheet> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  int? _countedValue;
  bool _busy = false;
  String? _error;

  int get _expected => widget.shift.summary?.expected ?? widget.shift.openingCash;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  String _signed(int value) => value == 0 ? rupiah(0) : '${value > 0 ? '+' : '-'}${rupiah(value.abs())}';

  Future<void> _close() async {
    if (_countedValue == null) {
      setState(() => _error = 'Hitung dan isi uang fisik di laci.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final closed = await widget.close(countedCash: _countedValue!, note: _note.text.trim());
      if (mounted) {
        Navigator.pop(context);
        final difference = closed.cashDifference ?? 0;
        showMessage(
          context,
          difference == 0
              ? 'Shift ${closed.number} ditutup. Uang laci pas.'
              : 'Shift ${closed.number} ditutup dengan selisih ${_signed(difference)}.',
        );
      }
    } on ApiException catch (error) {
      setState(() => _error = error.fieldError('counted_cash') ?? error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final difference = _countedValue == null ? null : _countedValue! - _expected;

    return FormSheet(
      title: 'Tutup shift ${widget.shift.number}',
      subtitle: 'Seharusnya ada ${rupiah(_expected)} di laci.',
      children: [
        MoneyField(
          controller: _counted,
          label: 'Uang fisik yang dihitung',
          autofocus: true,
          errorText: _error,
          onChanged: (value) => setState(() => _countedValue = _counted.text.isEmpty ? null : value),
        ),
        if (difference != null) ...[
          const SizedBox(height: 8),
          Text(
            difference == 0 ? 'Pas, tidak ada selisih.' : 'Selisih ${_signed(difference)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: difference == 0 ? colors.success : colors.warning),
          ),
        ],
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 255, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          onPressed: _busy ? null : _close,
          child: const Text('Tutup Shift'),
        ),
      ],
    );
  }
}
