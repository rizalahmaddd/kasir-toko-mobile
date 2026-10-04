import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../../receivables/presentation/receivable_payment_sheet.dart';
import '../data/sale_models.dart';
import '../data/sales_repository.dart';
import '../sales_controller.dart';
import 'receipt_sheet.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  Future<void> _void(BuildContext context, WidgetRef ref, SaleDetail sale) async {
    final reason = await promptText(
      context,
      title: SalesStrings.voidConfirmTitle(sale.number),
      label: SalesStrings.voidReasonLabel,
      hint: SalesStrings.voidReasonHint,
      confirmLabel: SalesStrings.voidTransaction,
      maxLength: 255,
    );
    if (reason == null) {
      return;
    }
    if (reason.isEmpty) {
      if (context.mounted) {
        showMessage(context, SalesStrings.voidReasonEmpty, isError: true);
      }
      return;
    }

    try {
      await ref.read(salesRepositoryProvider).voidSale(sale.id, reason);
      ref.read(dataChangesProvider).after({DataChange.sales});
      if (context.mounted) {
        showMessage(context, SalesStrings.voidSuccess);
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
        title: Text(sale.value?.number ?? SalesStrings.saleDetailTitle),
        actions: [
          if (sale.value != null && ref.watch(printerSettingsProvider).isConfigured)
            IconButton(
              tooltip: SalesStrings.printReceiptTooltip,
              icon: const Icon(AppIcons.printer, size: AppSizes.s20),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Summary Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
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
                      const SizedBox(height: AppSizes.s10),
                      Text(
                        rupiah(sale.total),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: sale.isVoided
                              ? muted
                              : sale.dueAmount > 0
                                  ? AppColors.amber600
                                  : AppColors.emerald600,
                          decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _MetaPill(
                            icon: AppIcons.user,
                            label: SalesStrings.cashierLabel(sale.cashierName),
                            isDark: isDark,
                          ),
                          if (sale.customer != null)
                            _MetaPill(
                              icon: AppIcons.userCheck,
                              label: sale.customer!.name,
                              isDark: isDark,
                            ),
                          if (sale.shiftNumber != null)
                            _MetaPill(
                              icon: AppIcons.wallet,
                              label: SalesStrings.shiftLabel('${sale.shiftNumber}'),
                              isDark: isDark,
                            ),
                        ],
                      ),
                      if (sale.isVoided) ...[
                        const SizedBox(height: AppSizes.s12),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s10),
                          decoration: BoxDecoration(
                            color: AppColors.red100,
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                            border: Border.all(color: AppColors.red300),
                          ),
                          child: Row(
                            children: [
                              const Icon(AppIcons.alertTriangle, size: AppSizes.s16, color: AppColors.red600),
                              const SizedBox(width: AppSizes.s8),
                              Expanded(
                                child: Text(
                                  SalesStrings.voidedBanner(
                                    sale.voidedAt == null ? '' : dateTime(sale.voidedAt!),
                                    sale.voidReason ?? '-',
                                  ),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.red600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.s16),

                // 2. Daftar Barang
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s14, AppSpacing.s16, AppSpacing.s10),
                        child: Row(
                          children: [
                            const Icon(AppIcons.shoppingBag, size: AppSizes.s16, color: AppColors.emerald600),
                            const SizedBox(width: AppSizes.s8),
                            const Text(
                              SalesStrings.itemListTitle,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              SalesStrings.itemCount(sale.items.length),
                              style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      for (int i = 0; i < sale.items.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, thickness: 1, color: isDark ? AppColors.slate700 : AppColors.slate100),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
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
                                    const SizedBox(height: AppSizes.s3),
                                    Text(
                                      SalesStrings.itemQuantityPrice(quantity(sale.items[i].quantity), sale.items[i].unit, rupiah(sale.items[i].price)),
                                      style: TextStyle(fontSize: 12, color: muted),
                                    ),
                                    if (sale.items[i].discountAmount > 0)
                                      Text(
                                        SalesStrings.itemDiscount(rupiah(sale.items[i].discountAmount)),
                                        style: const TextStyle(fontSize: 11, color: AppColors.red600, fontWeight: FontWeight.w500),
                                      ),
                                    if (sale.items[i].note != null && sale.items[i].note!.isNotEmpty)
                                      Text(
                                        SalesStrings.noteWithValue('${sale.items[i].note}'),
                                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: muted),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSizes.s12),
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

                const SizedBox(height: AppSizes.s16),

                // 3. Rincian Pembayaran
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        SalesStrings.paymentDetailsTitle,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSizes.s12),
                      _Row(SalesStrings.subtotal, rupiah(sale.subtotal)),
                      if (sale.discountAmount > 0) _Row(SalesStrings.discount, '-${rupiah(sale.discountAmount)}', color: AppColors.red600),
                      if (sale.taxAmount > 0) _Row(SalesStrings.taxLabel(quantity(sale.taxRate)), rupiah(sale.taxAmount)),
                      const SizedBox(height: AppSizes.s4),
                      Divider(height: 16, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      _Row(SalesStrings.totalTransaction, rupiah(sale.total), bold: true),
                      Divider(height: 16, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      for (final payment in sale.payments)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.slate700 : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(AppRadius.r6),
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
                      if (sale.cashReceived > 0) _Row(SalesStrings.cashReceived, rupiah(sale.cashReceived)),
                      if (sale.changeAmount > 0) _Row(SalesStrings.change, rupiah(sale.changeAmount)),
                      if (sale.dueAmount > 0)
                        _Row(SalesStrings.remainingCredit, rupiah(sale.dueAmount), color: colors.warning, bold: true),
                    ],
                  ),
                ),

                if (sale.note != null && sale.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate50,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                    ),
                    child: Text(SalesStrings.noteWithValue('${sale.note}'), style: TextStyle(fontSize: 12, color: muted)),
                  ),
                ],

                const SizedBox(height: AppSizes.s20),

                // 4. Action Buttons
                if (sale.canCollectPayment && sale.dueAmount > 0) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                    ),
                    onPressed: () => ReceivablePaymentSheet.show(
                      context,
                      saleId: sale.id,
                      number: sale.number,
                      due: sale.dueAmount,
                      customerName: sale.customer?.name,
                    ),
                    icon: const Icon(AppIcons.handCoins, size: AppSizes.s18),
                    label: Text(SalesStrings.collectPaymentButton(rupiah(sale.dueAmount)), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: AppSizes.s10),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                        ),
                        onPressed: () => ReceiptSheet.show(context, sale.id),
                        icon: const Icon(AppIcons.receiptText, size: AppSizes.s18),
                        label: const Text(SalesStrings.viewReceipt),
                      ),
                    ),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.whatsappGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                        ),
                        onPressed: () => openWhatsApp(context, sale.whatsappUrl),
                        icon: const Icon(AppIcons.messageCircle, size: AppSizes.s18),
                        label: const Text(SalesStrings.whatsapp),
                      ),
                    ),
                  ],
                ),

                if (sale.canVoid) ...[
                  const SizedBox(height: AppSizes.s10),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: colors.danger),
                    onPressed: onVoid,
                    icon: const Icon(AppIcons.ban, size: AppSizes.s18),
                    label: const Text(SalesStrings.voidTransaction),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700 : AppColors.slate100,
        borderRadius: BorderRadius.circular(AppRadius.r6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.s12, color: isDark ? AppColors.slate300 : AppColors.slate600),
          const SizedBox(width: AppSizes.s4),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3_5),
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

