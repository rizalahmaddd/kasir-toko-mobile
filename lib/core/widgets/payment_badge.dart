import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../theme/app_theme.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class PaymentBadge extends StatelessWidget {
  const PaymentBadge({
    super.key,
    required this.method,
    this.label,
  });

  final String method;
  final String? label;

  static const _labels = {
    PaymentMethods.cash: CoreStrings.paymentCash,
    PaymentMethods.qris: CoreStrings.paymentQris,
    PaymentMethods.transfer: CoreStrings.paymentTransfer,
    PaymentMethods.card: CoreStrings.paymentCard,
    'credit': CoreStrings.paymentCredit,
  };

  static const _icons = {
    PaymentMethods.cash: AppIcons.banknote,
    PaymentMethods.qris: AppIcons.qrCode,
    PaymentMethods.transfer: AppIcons.landmark,
    PaymentMethods.card: AppIcons.creditCard,
    'credit': AppIcons.handCoins,
  };

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final theme = Theme.of(context);

    final displayLabel = label ?? _labels[method] ?? method.toUpperCase();
    final icon = _icons[method] ?? AppIcons.wallet;

    final color = switch (method) {
      PaymentMethods.cash => status.success,
      PaymentMethods.qris => status.info,
      'credit' => status.warning,
      _ => theme.colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s7, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.r6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.s12, color: color),
          const SizedBox(width: AppSizes.s4),
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
