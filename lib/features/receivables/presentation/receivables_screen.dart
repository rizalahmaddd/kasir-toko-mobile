import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../receivables.dart';
import 'receivable_payment_sheet.dart';

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivables = ref.watch(receivablesProvider);
    final meta = receivables.value?.meta ?? const {};
    final colors = StatusColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

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
              Row(
                children: [
                  Expanded(child: StatTile(label: 'Total belum lunas', value: rupiah(asInt(meta['total_due'])), color: colors.warning, icon: LucideIcons.handCoins)),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(label: 'Pelanggan', value: '${asInt(meta['customer_count'])}', icon: LucideIcons.users)),
                ],
              ),
              const SizedBox(height: 12),
              SearchField(hint: 'No. transaksi, nama, atau HP pelanggan', onChanged: ref.read(receivablesSearchProvider.notifier).set),
            ],
          ),
        ),
        empty: const EmptyState(icon: LucideIcons.handCoins, title: 'Tidak ada kasbon', description: 'Semua kasbon sudah lunas.'),
        itemBuilder: (context, sale) {
          final age = DateTime.now().difference(sale.soldAt).inDays;

          return ListTile(
            onTap: () => context.push('/sale/${sale.id}'),
            title: Text(sale.customer?.name ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${sale.number} · ${dateOnly(sale.soldAt)} · ${age == 0 ? 'hari ini' : '$age hari'}\nTotal ${rupiah(sale.total)}, dibayar ${rupiah(sale.paidAmount)}',
              style: TextStyle(color: muted),
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(rupiah(sale.dueAmount), style: TextStyle(fontWeight: FontWeight.w700, color: colors.warning)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 30,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: () => ReceivablePaymentSheet.show(context, saleId: sale.id, number: sale.number, due: sale.dueAmount, customerName: sale.customer?.name),
                    child: const Text('Bayar'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
