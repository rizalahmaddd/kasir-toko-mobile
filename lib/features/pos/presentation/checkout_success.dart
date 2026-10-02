import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../../sales/data/sale_models.dart';
import '../../sales/presentation/receipt_sheet.dart';

/// Shown right after checkout. The change amount is what the cashier needs first.
class CheckoutSuccess extends ConsumerStatefulWidget {
  const CheckoutSuccess({super.key, required this.sale});

  final SaleDetail sale;

  static Future<void> show(BuildContext context, SaleDetail sale) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CheckoutSuccess(sale: sale),
      );

  @override
  ConsumerState<CheckoutSuccess> createState() => _CheckoutSuccessState();
}

class _CheckoutSuccessState extends ConsumerState<CheckoutSuccess> {
  SaleDetail get sale => widget.sale;

  @override
  void initState() {
    super.initState();
    if (ref.read(printerSettingsProvider).autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _print());
    }
  }

  void _print() => runPrint(context, () => ref.read(printerServiceProvider).printSale(sale.id));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrinter = ref.watch(printerSettingsProvider).isConfigured;
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
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.circleCheck, size: 36, color: colors.success),
              ),
              const SizedBox(height: 14),
              Text('Transaksi berhasil', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sale.number, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 18),
              if (sale.changeAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.success.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Kembalian',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.success, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rupiah(sale.changeAmount),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.success,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Text(
                  rupiah(sale.total),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (sale.dueAmount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Kasbon ${rupiah(sale.dueAmount)} atas nama ${sale.customer?.name ?? '-'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.warning, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 20),
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
              if (hasPrinter) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _print, icon: const Icon(LucideIcons.printer, size: 18), label: const Text('Cetak Struk')),
              ],
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Transaksi Baru')),
            ],
          ),
        ),
      ),
    );
  }
}
