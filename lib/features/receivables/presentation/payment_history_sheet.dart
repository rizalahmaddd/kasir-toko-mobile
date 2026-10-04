import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../sales/data/sale_models.dart';
import '../../sales/sales_controller.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

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
                title: ReceivableStrings.paymentHistoryTitle,
                subtitle: ReceivableStrings.paymentHistorySubtitle(number, customerName),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s4, AppSpacing.s20, AppSpacing.s24),
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
                            padding: const EdgeInsets.all(AppSpacing.s14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.slate900 : AppColors.slate50,
                              borderRadius: BorderRadius.circular(AppRadius.r14),
                              border: Border.all(
                                color: isDark ? AppColors.slate700 : AppColors.slate200,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(ReceivableStrings.totalBill, style: TextStyle(fontSize: 12.5, color: muted)),
                                    Text(
                                      rupiah(sale.total),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.s6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(ReceivableStrings.alreadyPaid, style: TextStyle(fontSize: 12.5, color: muted)),
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
                                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ReceivableStrings.remainingCredit,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.slate200 : AppColors.slate800,
                                      ),
                                    ),
                                    Text(
                                      sale.dueAmount > 0 ? rupiah(sale.dueAmount) : ReceivableStrings.paidOff,
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

                          const SizedBox(height: AppSizes.s18),
                          SectionTitle(ReceivableStrings.allIncomingTransactions(payments.length)),
                          const SizedBox(height: AppSizes.s6),

                          if (payments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
                              child: EmptyState(
                                icon: AppIcons.receiptText,
                                title: ReceivableStrings.noPaymentsTitle,
                                description: ReceivableStrings.noPaymentsDescription,
                              ),
                            )
                          else
                            for (final payment in payments) ...[
                              _PaymentTile(payment: payment),
                              const SizedBox(height: AppSizes.s8),
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
      PaymentMethods.cash => (AppIcons.banknote, AppColors.emerald500.withValues(alpha: 0.12), AppColors.emerald600),
      PaymentMethods.qris => (AppIcons.qrCode, AppColors.teal600.withValues(alpha: 0.12), AppColors.teal600),
      PaymentMethods.transfer => (AppIcons.arrowLeftRight, AppColors.blue500.withValues(alpha: 0.12), AppColors.blue600),
      _ => (AppIcons.creditCard, AppColors.violet500.withValues(alpha: 0.12), AppColors.violet600),
    };

    final isInitial = payment.kind == PaymentKinds.sale;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Method icon badge
          Container(
            padding: const EdgeInsets.all(AppSpacing.s9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.r10),
            ),
            child: Icon(icon, size: AppSizes.s18, color: iconColor),
          ),
          const SizedBox(width: AppSizes.s12),

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
                    const SizedBox(width: AppSizes.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                      decoration: BoxDecoration(
                        color: isInitial
                            ? (isDark ? AppColors.slate700 : AppColors.slate100)
                            : AppColors.emerald500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                      ),
                      child: Text(
                        isInitial ? ReceivableStrings.initialPayment : ReceivableStrings.settlement,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isInitial ? muted : AppColors.emerald600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s3),
                Text(
                  dateTime(payment.paidAt),
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
                if (payment.reference != null && payment.reference!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    ReceivableStrings.referencePrefix('${payment.reference}'),
                    style: TextStyle(fontSize: 11, color: muted, fontStyle: FontStyle.italic),
                  ),
                ],
                if (payment.cashierName != null && payment.cashierName!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    ReceivableStrings.receivedBy('${payment.cashierName}'),
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
