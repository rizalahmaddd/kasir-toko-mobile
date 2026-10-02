import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../sales/data/sale_models.dart';
import '../receivables.dart';
import 'receivable_payment_sheet.dart';

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivables = ref.watch(receivablesProvider);
    final meta = receivables.value?.meta ?? const {};
    final colors = StatusColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Piutang (kasbon)')),
      body: PagedListView(
        value: receivables,
        onLoadMore: () => ref.read(receivablesProvider.notifier).loadMore(),
        onRefresh: () => ref.refresh(receivablesProvider.future),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatTile(label: 'Total belum lunas', value: rupiah(asInt(meta['total_due'])), color: colors.warning, icon: LucideIcons.handCoins),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(label: 'Pelanggan', value: '${asInt(meta['customer_count'])}', icon: LucideIcons.users),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SearchField(hint: 'No. transaksi, nama, atau HP pelanggan', onChanged: ref.read(receivablesSearchProvider.notifier).set),
            ],
          ),
        ),
        empty: const EmptyState(icon: LucideIcons.handCoins, title: 'Tidak ada kasbon', description: 'Semua kasbon sudah lunas.'),
        padding: const EdgeInsets.only(bottom: 96),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/sale/${sale.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(LucideIcons.user, size: 16, color: colors.warning),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.customer?.name ?? 'Tanpa Nama',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
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
                              Text(' · ', style: TextStyle(color: muted, fontSize: 12)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: age > 14
                            ? colors.danger.withValues(alpha: 0.1)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        age == 0 ? 'Hari ini' : '$age hari',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: age > 14 ? colors.danger : muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sisa Kasbon', style: TextStyle(fontSize: 11, color: muted)),
                            const SizedBox(height: 2),
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
                            'Total ${rupiah(sale.total)}',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dibayar ${rupiah(sale.paidAmount)}',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 32,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                              Icon(LucideIcons.handCoins, size: 14),
                              SizedBox(width: 6),
                              Text('Bayar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
