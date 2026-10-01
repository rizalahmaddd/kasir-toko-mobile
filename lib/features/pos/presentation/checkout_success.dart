import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../sales/data/sale_models.dart';
import '../../sales/presentation/receipt_sheet.dart';

/// Shown right after checkout. The change amount is what the cashier needs first.
class CheckoutSuccess extends StatelessWidget {
  const CheckoutSuccess({super.key, required this.sale});

  final SaleDetail sale;

  static Future<void> show(BuildContext context, SaleDetail sale) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CheckoutSuccess(sale: sale),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(LucideIcons.circleCheck, size: 40, color: colors.success),
              const SizedBox(height: 12),
              Text('Transaksi berhasil', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(sale.number, textAlign: TextAlign.center, style: TextStyle(color: muted)),
              const SizedBox(height: 20),
              if (sale.changeAmount > 0) ...[
                Text('Kembalian', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                Text(
                  rupiah(sale.changeAmount),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: colors.success),
                ),
              ] else
                Text(
                  rupiah(sale.total),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              if (sale.dueAmount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Kasbon ${rupiah(sale.dueAmount)} atas nama ${sale.customer?.name ?? '-'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.warning, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ReceiptSheet.show(context, sale.id),
                      icon: const Icon(LucideIcons.receiptText, size: 18),
                      label: const Text('Lihat Struk'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openWhatsApp(context, sale.whatsappUrl),
                      icon: const Icon(LucideIcons.messageCircle, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Transaksi Baru')),
            ],
          ),
        ),
      ),
    );
  }
}
