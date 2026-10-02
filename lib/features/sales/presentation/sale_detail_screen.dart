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
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final colors = StatusColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label: sale.statusLabel,
                            tone: sale.isVoided
                                ? BadgeTone.danger
                                : sale.dueAmount > 0
                                    ? BadgeTone.warning
                                    : BadgeTone.success,
                          ),
                          const Spacer(),
                          Text(
                            dateTime(sale.soldAt),
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        rupiah(sale.total),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: sale.isVoided
                              ? muted
                              : sale.dueAmount > 0
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF059669),
                          decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _MetaPill(
                            icon: LucideIcons.user,
                            label: 'Kasir: ${sale.cashierName}',
                            isDark: isDark,
                          ),
                          if (sale.customer != null)
                            _MetaPill(
                              icon: LucideIcons.userCheck,
                              label: sale.customer!.name,
                              isDark: isDark,
                            ),
                          if (sale.shiftNumber != null)
                            _MetaPill(
                              icon: LucideIcons.wallet,
                              label: 'Shift #${sale.shiftNumber}',
                              isDark: isDark,
                            ),
                        ],
                      ),
                      if (sale.isVoided) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Dibatalkan ${sale.voidedAt == null ? '' : dateTime(sale.voidedAt!)}: ${sale.voidReason ?? '-'}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Daftar Barang
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.shoppingBag, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            const Text(
                              'Daftar Barang',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              '${sale.items.length} item',
                              style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      for (int i = 0; i < sale.items.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sale.items[i].productName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${quantity(sale.items[i].quantity)} ${sale.items[i].unit} × ${rupiah(sale.items[i].price)}',
                                      style: TextStyle(fontSize: 12, color: muted),
                                    ),
                                    if (sale.items[i].discountAmount > 0)
                                      Text(
                                        'Diskon -${rupiah(sale.items[i].discountAmount)}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                                      ),
                                    if (sale.items[i].note != null && sale.items[i].note!.isNotEmpty)
                                      Text(
                                        'Catatan: ${sale.items[i].note}',
                                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: muted),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                rupiah(sale.items[i].total),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Rincian Pembayaran
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Rincian Pembayaran',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _Row('Subtotal', rupiah(sale.subtotal)),
                      if (sale.discountAmount > 0) _Row('Diskon', '-${rupiah(sale.discountAmount)}', color: const Color(0xFFDC2626)),
                      if (sale.taxAmount > 0) _Row('Pajak ${quantity(sale.taxRate)}%', rupiah(sale.taxAmount)),
                      const SizedBox(height: 4),
                      Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      _Row('Total Transaksi', rupiah(sale.total), bold: true),
                      Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      for (final payment in sale.payments)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  payment.methodLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.slate300 : AppColors.slate800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                rupiah(payment.amount),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      if (sale.cashReceived > 0) _Row('Uang Diterima', rupiah(sale.cashReceived)),
                      if (sale.changeAmount > 0) _Row('Kembalian', rupiah(sale.changeAmount)),
                      if (sale.dueAmount > 0)
                        _Row('Sisa Kasbon', rupiah(sale.dueAmount), color: colors.warning, bold: true),
                    ],
                  ),
                ),

                if (sale.note != null && sale.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text('Catatan: ${sale.note}', style: TextStyle(fontSize: 12, color: muted)),
                  ),
                ],

                const SizedBox(height: 20),

                // 4. Action Buttons
                if (sale.canCollectPayment && sale.dueAmount > 0) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => ReceivablePaymentSheet.show(
                      context,
                      saleId: sale.id,
                      number: sale.number,
                      due: sale.dueAmount,
                      customerName: sale.customer?.name,
                    ),
                    icon: const Icon(LucideIcons.handCoins, size: 18),
                    label: Text('Catat Pelunasan ${rupiah(sale.dueAmount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => ReceiptSheet.show(context, sale.id),
                        icon: const Icon(LucideIcons.receiptText, size: 18),
                        label: const Text('Lihat Struk'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => openWhatsApp(context, sale.whatsappUrl),
                        icon: const Icon(LucideIcons.messageCircle, size: 18),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),

                if (sale.canVoid) ...[
                  const SizedBox(height: 10),
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, required this.isDark});

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? AppColors.slate300 : AppColors.slate600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: bold ? null : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

