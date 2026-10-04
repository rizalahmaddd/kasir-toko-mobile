import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../sales/data/sale_models.dart';
import '../receivables.dart';
import 'payment_history_sheet.dart';
import 'receivable_payment_sheet.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivables = ref.watch(receivablesProvider);
    final meta = receivables.value?.meta ?? const {};
    final colors = StatusColors.of(context);

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(ReceivableStrings.receivablesTitle),
        hint: ReceivableStrings.receivablesSearchHint,
        initialSearch: ref.watch(receivablesSearchProvider),
        onSearchChanged: ref.read(receivablesSearchProvider.notifier).set,
      ),
      body: PagedListView(
        value: receivables,
        onLoadMore: () => ref.read(receivablesProvider.notifier).loadMore(),
        onRefresh: () => ref.refresh(receivablesProvider.future),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatTile(label: ReceivableStrings.totalOutstanding, value: rupiah(asInt(meta['total_due'])), color: colors.warning, icon: AppIcons.handCoins),
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: StatTile(label: ReceivableStrings.customerLabel, value: '${asInt(meta['customer_count'])}', icon: AppIcons.users),
                ),
              ],
            ),
          ),
        ),
        empty: const EmptyState(icon: AppIcons.handCoins, title: ReceivableStrings.noReceivablesTitle, description: ReceivableStrings.noReceivablesDescription),
        padding: const EdgeInsets.only(bottom: AppSpacing.s96),
        itemBuilder: (context, sale) => _ReceivableCard(sale: sale),
      ),
    );
  }
}

class _ReceivableCard extends StatelessWidget {
  const _ReceivableCard({required this.sale});

  final SaleSummary sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final age = DateTime.now().difference(sale.soldAt).inDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r14),
          onTap: () => context.push(AppRoutes.saleDetail(sale.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                      ),
                      child: Icon(AppIcons.user, size: AppSizes.s16, color: colors.warning),
                    ),
                    const SizedBox(width: AppSizes.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.customer?.name ?? ReceivableStrings.unnamedCustomer,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSizes.s2),
                          Row(
                            children: [
                              Text(
                                sale.number,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(ReceivableStrings.metaSeparator, style: TextStyle(color: muted, fontSize: 12)),
                              Text(
                                dateOnly(sale.soldAt),
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: age > 14
                            ? colors.danger.withValues(alpha: 0.1)
                            : (isDark ? AppColors.slate700 : AppColors.slate100),
                        borderRadius: BorderRadius.circular(AppRadius.r6),
                      ),
                      child: Text(
                        age == 0 ? ReceivableStrings.today : ReceivableStrings.daysAgo(age),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: age > 14 ? colors.danger : muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : AppColors.slate50,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ReceivableStrings.remainingCredit, style: TextStyle(fontSize: 11, color: muted)),
                            const SizedBox(height: AppSizes.s2),
                            Text(
                              rupiah(sale.dueAmount),
                              style: AppTypography.money(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: colors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            ReceivableStrings.totalAmount(rupiah(sale.total)),
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: AppSizes.s2),
                          Text(
                            ReceivableStrings.paidAmount(rupiah(sale.paidAmount)),
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSizes.s8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: ReceivableStrings.paymentHistoryTooltip,
                        icon: const Icon(AppIcons.history, size: AppSizes.s16),
                        onPressed: () => PaymentHistorySheet.show(
                          context,
                          saleId: sale.id,
                          number: sale.number,
                          customerName: sale.customer?.name,
                        ),
                      ),
                      const SizedBox(width: AppSizes.s4),
                      SizedBox(
                        height: 32,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => ReceivablePaymentSheet.show(
                            context,
                            saleId: sale.id,
                            number: sale.number,
                            due: sale.dueAmount,
                            customerName: sale.customer?.name,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.handCoins, size: AppSizes.s14),
                              SizedBox(width: AppSizes.s6),
                              Text(ReceivableStrings.payButton, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
