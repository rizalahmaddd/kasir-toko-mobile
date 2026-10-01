import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/pos_providers.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../../receivables/presentation/receivable_payment_sheet.dart';
import '../../shift/shift_controller.dart';
import '../data/sale_models.dart';
import '../data/sales_repository.dart';
import '../sales_controller.dart';
import 'receipt_sheet.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  Future<void> _void(BuildContext context, WidgetRef ref, SaleDetail sale) async {
    final reason = await promptText(
      context,
      title: 'Batalkan ${sale.number}?',
      label: 'Alasan pembatalan',
      hint: 'mis. salah input barang',
      confirmLabel: 'Batalkan Transaksi',
      maxLength: 255,
    );
    if (reason == null) {
      return;
    }
    if (reason.isEmpty) {
      if (context.mounted) {
        showMessage(context, 'Tulis alasan pembatalan.', isError: true);
      }
      return;
    }

    try {
      await ref.read(salesRepositoryProvider).voidSale(sale.id, reason);
      ref
        ..invalidate(saleDetailProvider(sale.id))
        ..invalidate(salesProvider)
        ..invalidate(currentShiftProvider)
        ..invalidate(catalogProvider);
      if (context.mounted) {
        showMessage(context, 'Transaksi dibatalkan. Stok dikembalikan.');
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(saleDetailProvider(saleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(sale.value?.number ?? 'Detail transaksi'),
        actions: [
          if (sale.value != null && ref.watch(printerSettingsProvider).isConfigured)
            IconButton(
              tooltip: 'Cetak struk',
              icon: const Icon(LucideIcons.printer, size: 20),
              onPressed: () => runPrint(context, () => ref.read(printerServiceProvider).printSale(saleId)),
            ),
        ],
      ),
      body: AsyncView(
        value: sale,
        onRetry: () => ref.invalidate(saleDetailProvider(saleId)),
        data: (sale) => _Body(sale: sale, onVoid: () => _void(context, ref, sale)),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.sale, required this.onVoid});

  final SaleDetail sale;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final colors = StatusColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StatusBadge(
                      label: sale.statusLabel,
                      tone: sale.isVoided ? BadgeTone.danger : sale.dueAmount > 0 ? BadgeTone.warning : BadgeTone.success,
                    ),
                    const Spacer(),
                    Text(dateTime(sale.soldAt), style: TextStyle(color: muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(rupiah(sale.total), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  'Kasir ${sale.cashierName}${sale.customer == null ? '' : ' · ${sale.customer!.name}'}',
                  style: TextStyle(color: muted),
                ),
                if (sale.isVoided) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Dibatalkan ${sale.voidedAt == null ? '' : dateTime(sale.voidedAt!)}: ${sale.voidReason ?? '-'}',
                    style: TextStyle(color: colors.danger),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      for (final item in sale.items)
                        ListTile(
                          title: Text(item.productName),
                          subtitle: Text(
                            [
                              '${quantity(item.quantity)} ${item.unit} × ${rupiah(item.price)}',
                              if (item.discountAmount > 0) 'diskon -${rupiah(item.discountAmount)}',
                              if (item.note != null && item.note!.isNotEmpty) item.note!,
                            ].join(' · '),
                          ),
                          trailing: Text(rupiah(item.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _Row('Subtotal', rupiah(sale.subtotal)),
                        if (sale.discountAmount > 0) _Row('Diskon', '-${rupiah(sale.discountAmount)}'),
                        if (sale.taxAmount > 0) _Row('Pajak ${quantity(sale.taxRate)}%', rupiah(sale.taxAmount)),
                        _Row('Total', rupiah(sale.total), bold: true),
                        const Divider(height: 24),
                        for (final payment in sale.payments)
                          _Row(
                            '${payment.kind == 'receivable' ? 'Pelunasan ' : ''}${payment.methodLabel}${payment.reference == null ? '' : ' (${payment.reference})'}',
                            rupiah(payment.amount),
                          ),
                        if (sale.cashReceived > 0) _Row('Uang diterima', rupiah(sale.cashReceived)),
                        if (sale.changeAmount > 0) _Row('Kembalian', rupiah(sale.changeAmount)),
                        if (sale.dueAmount > 0) _Row('Sisa kasbon', rupiah(sale.dueAmount), color: colors.warning),
                      ],
                    ),
                  ),
                ),
                if (sale.note != null && sale.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Catatan: ${sale.note}', style: TextStyle(color: muted)),
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
                if (sale.canCollectPayment && sale.dueAmount > 0) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => ReceivablePaymentSheet.show(
                      context,
                      saleId: sale.id,
                      number: sale.number,
                      due: sale.dueAmount,
                      customerName: sale.customer?.name,
                    ),
                    icon: const Icon(LucideIcons.handCoins, size: 18),
                    label: Text('Catat Pelunasan ${rupiah(sale.dueAmount)}'),
                  ),
                ],
                if (sale.canVoid) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: colors.danger),
                    onPressed: onVoid,
                    icon: const Icon(LucideIcons.ban, size: 18),
                    label: const Text('Batalkan Transaksi'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
