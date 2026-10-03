import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../sales/data/sale_models.dart';
import '../../sales/sales_controller.dart';

class PaymentHistorySheet extends ConsumerWidget {
  const PaymentHistorySheet({
    super.key,
    required this.saleId,
    required this.number,
    this.customerName,
  });

  final int saleId;
  final String number;
  final String? customerName;

  static Future<void> show(
    BuildContext context, {
    required int saleId,
    required String number,
    String? customerName,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => PaymentHistorySheet(
          saleId: saleId,
          number: number,
          customerName: customerName,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final saleAsync = ref.watch(saleDetailProvider(saleId));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BottomSheetHeader(
                title: 'Riwayat Pembayaran',
                subtitle: '$number${customerName != null ? ' · $customerName' : ''}',
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: saleAsync.when(
                    loading: () => const SalesListSkeleton(
                      itemCount: 3,
                      showSummary: false,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                    ),
                    error: (error, _) => ErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(saleDetailProvider(saleId)),
                    ),
                    data: (sale) {
                      final payments = sale.payments;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Financial Summary Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Tagihan', style: TextStyle(fontSize: 12.5, color: muted)),
                                    Text(
                                      rupiah(sale.total),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Sudah Dibayar', style: TextStyle(fontSize: 12.5, color: muted)),
                                    Text(
                                      rupiah(sale.paidAmount),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Sisa Kasbon',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.slate200 : AppColors.slate800,
                                      ),
                                    ),
                                    Text(
                                      sale.dueAmount > 0 ? rupiah(sale.dueAmount) : 'Lunas',
                                      style: AppTypography.money(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: sale.dueAmount > 0 ? colors.warning : colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),
                          SectionTitle('Semua Transaksi Masuk (${payments.length})'),
                          const SizedBox(height: 6),

                          if (payments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: EmptyState(
                                icon: LucideIcons.receiptText,
                                title: 'Belum ada pembayaran',
                                description: 'Belum ada catatan pembayaran yang tercatat pada kasbon ini.',
                              ),
                            )
                          else
                            for (final payment in payments) ...[
                              _PaymentTile(payment: payment),
                              const SizedBox(height: 8),
                            ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final SalePayment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final (icon, iconBg, iconColor) = switch (payment.method.toLowerCase()) {
      'cash' => (LucideIcons.banknote, const Color(0xFF10B981).withValues(alpha: 0.12), const Color(0xFF059669)),
      'qris' => (LucideIcons.qrCode, const Color(0xFF0D9488).withValues(alpha: 0.12), const Color(0xFF0D9488)),
      'transfer' => (LucideIcons.arrowLeftRight, const Color(0xFF3B82F6).withValues(alpha: 0.12), const Color(0xFF2563EB)),
      _ => (LucideIcons.creditCard, const Color(0xFF8B5CF6).withValues(alpha: 0.12), const Color(0xFF7C3AED)),
    };

    final isInitial = payment.kind == 'sale';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Method icon badge
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),

          // Detail info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      payment.methodLabel,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isInitial
                            ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                            : const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isInitial ? 'Pembayaran Awal' : 'Pelunasan',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isInitial ? muted : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dateTime(payment.paidAt),
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
                if (payment.reference != null && payment.reference!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${payment.reference}',
                    style: TextStyle(fontSize: 11, color: muted, fontStyle: FontStyle.italic),
                  ),
                ],
                if (payment.cashierName != null && payment.cashierName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Penerima: ${payment.cashierName}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ],
            ),
          ),

          // Amount
          Text(
            rupiah(payment.amount),
            style: AppTypography.money(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.success,
            ),
          ),
        ],
      ),
    );
  }
}
