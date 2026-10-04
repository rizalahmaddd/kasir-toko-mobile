import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';

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
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isAtMin ? CoreStrings.quantityRemove : CoreStrings.quantityDecrease,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: const EdgeInsets.all(AppSpacing.s8),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: Icon(isAtMin ? AppIcons.trash2 : AppIcons.minus),
            onPressed: _decrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
            child: Text(
              unit == null ? quantity(value) : CoreStrings.quantityWithUnit(quantity(value), unit!),
              style: AppTypography.quantity(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: CoreStrings.quantityIncrease,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            padding: const EdgeInsets.all(AppSpacing.s8),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: const Icon(AppIcons.plus),
            onPressed: _increment,
          ),
        ],
      ),
    );
  }
}
