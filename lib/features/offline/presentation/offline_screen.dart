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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Mode offline')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection Status Hero
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: reachable
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : colors.warning.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (reachable ? const Color(0xFF10B981) : colors.warning).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          reachable ? LucideIcons.cloudCheck : LucideIcons.cloudOff,
                          size: 22,
                          color: reachable ? const Color(0xFF059669) : colors.warning,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  reachable ? 'Terhubung ke Server' : 'Server Tidak Terjangkau',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (reachable ? const Color(0xFF10B981) : colors.warning).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    reachable ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: reachable ? const Color(0xFF059669) : colors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              reachable
                                  ? 'Transaksi kasir langsung tersinkronisasi otomatis ke server.'
                                  : 'Kasir tetap bisa berjualan. Transaksi disimpan di HP lalu dikirim otomatis saat online.',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Local Catalog Card
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
                        'KATALOG DI PERANGKAT',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      InfoRow('Produk tersimpan', snapshot == null ? 'Belum ada' : thousands(snapshot.products.length), bold: true),
                      InfoRow('Terakhir diperbarui', snapshot == null ? '-' : dateTime(snapshot.updatedAt)),
                      const SizedBox(height: 4),
                      Text(
                        'Diperbarui otomatis tiap 30 menit selama online agar harga dan stok tetap akurat.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _downloading ? null : _download,
                        icon: _downloading
                            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.download, size: 16),
                        label: const Text('Perbarui Katalog Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: SectionTitle(
                        'Antrean Transaksi (${queue.length})',
                      ),
                    ),
                    if (queue.isNotEmpty)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: sync.syncing ? null : () => _sync(includeFailed: true),
                        icon: sync.syncing
                            ? const SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.send, size: 14),
                        label: const Text('Kirim Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (sync.lastSyncAt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text('Percobaan sinkronisasi terakhir ${timeOnly(sync.lastSyncAt!)}', style: TextStyle(color: muted, fontSize: 12)),
                  ),
                if (failed > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.circleAlert, size: 16, color: colors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$failed transaksi ditolak server. Buka di keranjang kasir untuk diperbaiki atau hapus.',
                            style: TextStyle(color: colors.danger, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (queue.isEmpty)
                  const EmptyState(icon: LucideIcons.circleCheck, title: 'Semua transaksi sudah terkirim', description: 'Tidak ada antrean transaksi offline yang tertunda.')
                else
                  Column(
                    children: [
                      for (final sale in queue)
                        _QueuedSaleCard(
                          sale: sale,
                          onOpenInCart: () => _openInCart(sale),
                          onDelete: () => _delete(sale),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedSaleCard extends StatelessWidget {
  const _QueuedSaleCard({
    required this.sale,
    required this.onOpenInCart,
    required this.onDelete,
  });

  final QueuedSale sale;
  final VoidCallback onOpenInCart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isFailed = sale.status == QueuedStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFailed
              ? colors.danger.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rupiah(sale.total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              StatusBadge(
                label: isFailed ? 'Ditolak Server' : 'Menunggu Kirim',
                tone: isFailed ? BadgeTone.danger : BadgeTone.warning,
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onSelected: (action) => action == 'cart' ? onOpenInCart() : onDelete(),
                itemBuilder: (_) => [
                  if (isFailed) const PopupMenuItem(value: 'cart', child: Text('Buka di keranjang')),
                  const PopupMenuItem(value: 'delete', child: Text('Hapus transaksi')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              dateTime(sale.createdAt),
              '${quantity(sale.itemCount)} barang',
              if (sale.customerName != null) sale.customerName!,
            ].join(' · '),
            style: TextStyle(color: muted, fontSize: 12),
          ),
          if (sale.error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sale.error!,
                style: TextStyle(color: colors.danger, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
