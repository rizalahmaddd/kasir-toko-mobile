import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';

class PaymentAmountPanel extends StatelessWidget {
  const PaymentAmountPanel({
    super.key,
    required this.total,
    this.remaining,
  });

  final int total;
  final int? remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : AppColors.slate900.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                remaining == null ? 'Total tagihan' : 'Sisa tagihan',
                style: TextStyle(
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (remaining != null)
                Text(
                  'dari ${rupiah(total)}',
                  style: TextStyle(
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(remaining ?? total),
              style: AppTypography.money(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
