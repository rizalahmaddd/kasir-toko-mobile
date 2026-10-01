import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/cart_controller.dart';
import '../catalog_snapshot.dart';
import '../offline_queue.dart';

class OfflineScreen extends ConsumerStatefulWidget {
  const OfflineScreen({super.key});

  @override
  ConsumerState<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends ConsumerState<OfflineScreen> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final snapshot = await ref.read(catalogSnapshotProvider.notifier).download();
      if (mounted) {
        showMessage(context, '${snapshot.products.length} produk tersimpan di perangkat.');
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<void> _sync({bool includeFailed = false}) async {
    final sent = await ref.read(offlineQueueProvider.notifier).sync(includeFailed: includeFailed);
    if (!mounted) {
      return;
    }
    final left = ref.read(myQueueProvider).length;
    showMessage(
      context,
      sent > 0
          ? '$sent transaksi terkirim.${left > 0 ? ' $left masih menunggu.' : ''}'
          : (ref.read(serverReachableProvider) ? 'Tidak ada transaksi yang bisa dikirim.' : 'Server masih belum terjangkau.'),
      isError: sent == 0 && left > 0,
    );
  }

  Future<void> _openInCart(QueuedSale sale) async {
    if (!ref.read(cartProvider).isEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Ganti isi keranjang?',
        message: 'Keranjang kasir sekarang akan diganti dengan transaksi ini.',
        confirmLabel: 'Ganti',
      );
      if (!ok) {
        return;
      }
    }
    ref.read(cartProvider.notifier).load(sale.cart);
    ref.read(offlineQueueProvider.notifier).remove(sale.clientUuid);
    if (mounted) {
      context.go('/pos');
      showMessage(context, 'Periksa keranjang lalu bayar ulang. Uang yang sudah diterima tetap dihitung.');
    }
  }

  Future<void> _delete(QueuedSale sale) async {
    final ok = await confirmAction(
      context,
      title: 'Hapus transaksi offline?',
      message: 'Transaksi ${rupiah(sale.total)} tidak akan pernah tercatat di server. Pastikan uangnya sudah dikembalikan atau dicatat ulang.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (ok) {
      ref.read(offlineQueueProvider.notifier).remove(sale.clientUuid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(catalogSnapshotProvider).value;
    final queue = ref.watch(myQueueProvider);
    final sync = ref.watch(syncStateProvider);
    final reachable = ref.watch(serverReachableProvider);
    final colors = StatusColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final failed = queue.where((sale) => sale.status == QueuedStatus.failed).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Mode offline')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(reachable ? LucideIcons.cloud : LucideIcons.cloudOff, color: reachable ? colors.success : colors.warning),
                    title: Text(reachable ? 'Terhubung ke server' : 'Server tidak terjangkau'),
                    subtitle: Text(
                      reachable
                          ? 'Transaksi langsung tercatat di server.'
                          : 'Kasir tetap bisa berjualan memakai katalog di perangkat. Transaksi disimpan lalu dikirim otomatis.',
                    ),
                  ),
                ),
                const SectionTitle('Katalog di perangkat'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InfoRow('Produk tersimpan', snapshot == null ? 'Belum ada' : thousands(snapshot.products.length)),
                        InfoRow('Diperbarui', snapshot == null ? '-' : dateTime(snapshot.updatedAt)),
                        const SizedBox(height: 4),
                        Text(
                          'Diperbarui otomatis tiap 30 menit selama online. Harga & stok bisa berbeda dari server sampai diperbarui.',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _downloading ? null : _download,
                          icon: _downloading
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(LucideIcons.download, size: 18),
                          label: const Text('Perbarui Sekarang'),
                        ),
                      ],
                    ),
                  ),
                ),
                SectionTitle(
                  'Transaksi menunggu dikirim (${queue.length})',
                  trailing: queue.isEmpty
                      ? null
                      : TextButton.icon(
                          onPressed: sync.syncing ? null : () => _sync(includeFailed: true),
                          icon: sync.syncing
                              ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(LucideIcons.send, size: 16),
                          label: const Text('Kirim sekarang'),
                        ),
                ),
                if (sync.lastSyncAt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text('Percobaan terakhir ${timeOnly(sync.lastSyncAt!)}', style: TextStyle(color: muted, fontSize: 13)),
                  ),
                if (failed > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '$failed transaksi ditolak server. Buka di keranjang untuk diperbaiki lalu bayar ulang, atau hapus.',
                      style: TextStyle(color: colors.danger),
                    ),
                  ),
                if (queue.isEmpty)
                  const EmptyState(icon: LucideIcons.circleCheck, title: 'Semua transaksi sudah terkirim')
                else
                  Card(
                    child: Column(
                      children: [
                        for (final (i, sale) in queue.indexed) ...[
                          if (i > 0) const Divider(),
                          ListTile(
                            leading: Icon(
                              sale.status == QueuedStatus.failed ? LucideIcons.circleAlert : LucideIcons.clock,
                              color: sale.status == QueuedStatus.failed ? colors.danger : colors.warning,
                            ),
                            title: Text('${rupiah(sale.total)} · ${quantity(sale.itemCount)} barang'),
                            subtitle: Text(
                              [dateTime(sale.createdAt), ?sale.customerName, if (sale.error != null) sale.error!].join(' · '),
                              style: TextStyle(color: sale.status == QueuedStatus.failed ? colors.danger : muted),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) => action == 'cart' ? _openInCart(sale) : _delete(sale),
                              // A pending sale may already be stored on the server, so only rejected ones go back to the cart.
                              itemBuilder: (_) => [
                                if (sale.status == QueuedStatus.failed) const PopupMenuItem(value: 'cart', child: Text('Buka di keranjang')),
                                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin strip above the cashier screen while offline or while sales wait to be sent.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref.watch(serverReachableProvider);
    final waiting = ref.watch(myQueueProvider).length;
    final syncing = ref.watch(syncStateProvider).syncing;
    if (reachable && waiting == 0) {
      return const SizedBox.shrink();
    }

    final colors = StatusColors.of(context);
    final color = reachable ? colors.info : colors.warning;
    final text = [
      if (!reachable) 'Offline — memakai katalog di perangkat',
      if (waiting > 0) syncing ? 'Mengirim $waiting transaksi…' : '$waiting transaksi menunggu dikirim',
    ].join(' · ');

    return Material(
      color: color.withValues(alpha: 0.14),
      child: InkWell(
        onTap: () => context.push('/offline'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(reachable ? LucideIcons.refreshCw : LucideIcons.cloudOff, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
              Icon(LucideIcons.chevronRight, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
