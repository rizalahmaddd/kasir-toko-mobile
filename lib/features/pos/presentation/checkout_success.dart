import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../../sales/data/sale_models.dart';
import '../../sales/presentation/receipt_sheet.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _print();
        if (mounted && sale.kitchenTickets.isNotEmpty) {
          await _printKitchen();
        }
      });
    }
  }

  Future<void> _print() => runPrint(context, () => ref.read(printerServiceProvider).printSale(sale.id));

  Future<void> _printKitchen() => runPrint(
        context,
        () async {
          for (final ticket in sale.kitchenTickets) {
            await ref.read(printerServiceProvider).printKitchenTicket(ticket);
          }
        },
        success: PrintingStrings.kitchenTicketPrinted,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrinter = ref.watch(printerSettingsProvider).isConfigured;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s20),
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
                child: Icon(AppIcons.circleCheck, size: AppSizes.s36, color: colors.success),
              ),
              const SizedBox(height: AppSizes.s14),
              Text(PosStrings.transactionSuccessTitle, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSizes.s2),
              Text(sale.number, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: AppSizes.s18),
              if (sale.changeAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s14, horizontal: AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                    border: Border.all(color: colors.success.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        PosStrings.changeLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.success, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: AppSizes.s4),
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
                const SizedBox(height: AppSizes.s10),
                Text(
                  PosStrings.creditNote(rupiah(sale.dueAmount), sale.customer?.name ?? '-'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.warning, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: AppSizes.s20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ReceiptSheet.show(context, sale.id),
                      icon: const Icon(AppIcons.receiptText, size: AppSizes.s18),
                      label: const Text(PosStrings.viewReceiptButton),
                    ),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openWhatsApp(context, sale.whatsappUrl),
                      icon: const Icon(AppIcons.messageCircle, size: AppSizes.s18),
                      label: const Text(PosStrings.whatsappButton),
                    ),
                  ),
                ],
              ),
              if (hasPrinter) ...[
                const SizedBox(height: AppSizes.s8),
                OutlinedButton.icon(onPressed: _print, icon: const Icon(AppIcons.printer, size: AppSizes.s18), label: const Text(PosStrings.printReceiptButton)),
                if (sale.kitchenTickets.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s8),
                  OutlinedButton.icon(onPressed: _printKitchen, icon: const Icon(AppIcons.chefHat, size: AppSizes.s18), label: const Text(PosStrings.printKitchenTicket)),
                ],
              ],
              const SizedBox(height: AppSizes.s8),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text(PosStrings.newTransactionButton)),
            ],
          ),
        ),
      ),
    );
  }
}
