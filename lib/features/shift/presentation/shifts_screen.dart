import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../shifts_providers.dart';

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(shiftsStatusProvider);
    final colors = StatusColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat shift')),
      body: Column(
        children: [
          ChoiceChips<String>(
            options: const [(null, 'Semua'), ('open', 'Sedang buka'), ('closed', 'Ditutup'), ('variance', 'Ada selisih')],
            selected: status,
            onSelected: ref.read(shiftsStatusProvider.notifier).set,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedListView(
              value: ref.watch(shiftsProvider),
              onLoadMore: () => ref.read(shiftsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(shiftsProvider.future),
              empty: const EmptyState(icon: LucideIcons.wallet, title: 'Belum ada shift'),
              itemBuilder: (context, shift) {
                final difference = shift.cashDifference ?? 0;

                return ListTile(
                  onTap: () => context.push('/shift/${shift.id}'),
                  title: Row(
                    children: [
                      Text(shift.number, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (shift.isOpen)
                        const StatusBadge(label: 'Buka', tone: BadgeTone.success)
                      else if (difference != 0)
                        StatusBadge(label: difference > 0 ? 'Lebih' : 'Kurang', tone: BadgeTone.warning),
                    ],
                  ),
                  subtitle: Text(
                    '${shift.cashierName} · ${dateTime(shift.openedAt)}${shift.closedAt == null ? '' : ' – ${timeOnly(shift.closedAt!)}'}',
                    style: TextStyle(color: muted),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(rupiah(shift.salesTotal ?? 0)),
                      if (difference != 0)
                        Text(
                          '${difference > 0 ? '+' : '-'}${rupiah(difference.abs())}',
                          style: TextStyle(fontSize: 12, color: colors.warning, fontWeight: FontWeight.w600),
                        )
                      else
                        Text('${shift.salesCount ?? 0} transaksi', style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
