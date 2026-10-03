import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

/// Single-field dialog. Returns the trimmed text, or null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String initialValue = '',
  String? hint,
  String? suffix,
  int? maxLength,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
      hint: hint,
      suffix: suffix,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initialValue,
    this.hint,
    this.suffix,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialValue;
  final String? hint;
  final String? suffix;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, suffixText: widget.suffix),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(CoreStrings.actionCancel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
