import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

class PaymentBadge extends StatelessWidget {
  const PaymentBadge({
    super.key,
    required this.method,
    this.label,
  });

  final String method;
  final String? label;

  static const _labels = {
    'cash': 'Tunai',
    'qris': 'QRIS',
    'transfer': 'Transfer',
    'card': 'Kartu',
    'credit': 'Kasbon',
  };

  static const _icons = {
    'cash': LucideIcons.banknote,
    'qris': LucideIcons.qrCode,
    'transfer': LucideIcons.landmark,
    'card': LucideIcons.creditCard,
    'credit': LucideIcons.handCoins,
  };

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final theme = Theme.of(context);

    final displayLabel = label ?? _labels[method] ?? method.toUpperCase();
    final icon = _icons[method] ?? LucideIcons.wallet;

    final color = switch (method) {
      'cash' => status.success,
      'qris' => status.info,
      'credit' => status.warning,
      _ => theme.colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
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
