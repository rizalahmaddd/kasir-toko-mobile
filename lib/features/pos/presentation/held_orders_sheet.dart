import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';

final heldOrdersProvider = FutureProvider.autoDispose<List<HeldOrder>>((ref) => ref.watch(posRepositoryProvider).heldOrders());

class HeldOrdersSheet extends ConsumerWidget {
  const HeldOrdersSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const FractionallySizedBox(heightFactor: 0.75, child: HeldOrdersSheet()),
      );

  Future<void> _resume(BuildContext context, WidgetRef ref, HeldOrder order) async {
    if (!ref.read(cartProvider).isEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ganti keranjang sekarang?'),
          content: const Text('Keranjang yang sedang dibuka akan dikosongkan. Tunda dulu kalau masih dibutuhkan.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ganti Keranjang')),
          ],
        ),
      );
      if (replace != true) {
        return;
      }
    }

    try {
      final resumed = await ref.read(posRepositoryProvider).resumeHeldOrder(order.id);
      final cart = ref.read(cartProvider.notifier)..load(resumed.cart ?? const {});
      ref.invalidate(posConfigProvider);
      final notices = await cart.syncWithServer();

      if (context.mounted) {
        Navigator.pop(context);
        showMessage(context, notices.isEmpty ? '${resumed.label ?? 'Pesanan'} dilanjutkan.' : notices.join('\n'));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, HeldOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${order.label ?? 'pesanan'}?'),
        content: const Text('Keranjang yang ditunda ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(posRepositoryProvider).deleteHeldOrder(order.id);
      ref
        ..invalidate(heldOrdersProvider)
        ..invalidate(posConfigProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(heldOrdersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Transaksi tertunda', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: AsyncView(
            value: orders,
            onRetry: () => ref.invalidate(heldOrdersProvider),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    icon: LucideIcons.clock,
                    title: 'Tidak ada transaksi tertunda',
                    description: 'Tekan Tunda di keranjang untuk menyimpan belanjaan pelanggan sementara.',
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final order = list[index];
                      return ListTile(
                        title: Text(order.label ?? 'Pesanan', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${quantity(order.itemCount)} barang · ${timeOnly(order.createdAt)}'),
                        onTap: () => _resume(context, ref, order),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(rupiah(order.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                            IconButton(
                              tooltip: 'Hapus',
                              icon: const Icon(LucideIcons.trash2, size: 18),
                              onPressed: () => _delete(context, ref, order),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
