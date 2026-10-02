import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_typography.dart';
import '../utils/formatters.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.step = 1,
    this.unit,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double step;
  final String? unit;

  void _decrement() {
    HapticFeedback.lightImpact();
    onChanged(value - step);
  }

  void _increment() {
    HapticFeedback.lightImpact();
    onChanged(value + step);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAtMin = value <= min;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isAtMin ? 'Hapus' : 'Kurangi',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: Icon(isAtMin ? LucideIcons.trash2 : LucideIcons.minus),
            onPressed: _decrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              unit == null ? quantity(value) : '${quantity(value)} $unit',
              style: AppTypography.quantity(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Tambah',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: const Icon(LucideIcons.plus),
            onPressed: _increment,
          ),
        ],
      ),
    );
  }
}
