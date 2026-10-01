import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/formatters.dart';

/// Rupiah input that shows thousand separators while typing ("150.000").
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label,
    this.autofocus = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsFormatter()],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(labelText: label, prefixText: 'Rp ', errorText: errorText),
      onChanged: onChanged == null ? null : (value) => onChanged!(parseRupiah(value)),
      onSubmitted: onSubmitted == null ? null : (value) => onSubmitted!(parseRupiah(value)),
    );
  }
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final formatted = thousands(parseRupiah(newValue.text));

    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
