import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
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
        useSafeArea: true,
        builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: HeldOrdersSheet()),
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
      ref.read(heldOrderPreviewsProvider.notifier).remove(order.id);
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(posRepositoryProvider).deleteHeldOrder(order.id);
      ref.read(heldOrderPreviewsProvider.notifier).remove(order.id);
      ref
        ..invalidate(heldOrdersProvider)
        ..invalidate(posConfigProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  static String _relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 45) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else if (diff.inDays == 1) {
      return 'Kemarin';
    } else {
      return '${diff.inDays} hr lalu';
    }
  }

  static String? _extractCartPreview(Map<String, dynamic>? cart) {
    if (cart == null) return null;
    final items = (cart['items'] as List?) ?? const [];
    if (items.isEmpty) return null;
    final names = items
        .map((item) {
          final name = item['name'] ?? item['product_name'] ?? 'Item';
          final qty = item['quantity'] ?? 1;
          return '${quantity(qty)}x $name';
        })
        .take(3)
        .join(', ');
    return items.length > 3 ? '$names, ...' : names;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(heldOrdersProvider);
    final previews = ref.watch(heldOrderPreviewsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AsyncView(
      value: orders,
      onRetry: () => ref.invalidate(heldOrdersProvider),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(
            title: 'Transaksi Tertunda',
            subtitle: list.isEmpty ? null : '${list.length} pesanan tersimpan',
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: LucideIcons.clock,
                    title: 'Tidak Ada Transaksi Tertunda',
                    description: 'Tekan tombol "Tunda" di keranjang kasir untuk menyimpan transaksi sementara.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = list[index];
                      final preview = previews[order.id] ?? _extractCartPreview(order.cart);
                      return _HeldOrderCard(
                        order: order,
                        isDark: isDark,
                        preview: preview,
                        timeFormatted: '${_relativeTime(order.createdAt)} · ${timeOnly(order.createdAt)}',
                        onResume: () => _resume(context, ref, order),
                        onDelete: () => _delete(context, ref, order),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeldOrderCard extends StatelessWidget {
  const _HeldOrderCard({
    required this.order,
    required this.isDark,
    required this.preview,
    required this.timeFormatted,
    required this.onResume,
    required this.onDelete,
  });

  final HeldOrder order;
  final bool isDark;
  final String? preview;
  final String timeFormatted;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = order.label?.trim().isNotEmpty == true ? order.label! : 'Pesanan #${order.id}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onResume,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Line 1: Badge #ID + Title + Price
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.pause, size: 10, color: Color(0xFFD97706)),
                          const SizedBox(width: 3),
                          Text(
                            '#${order.id}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rupiah(order.total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // Line 2: Items count, time info + Actions (Delete & Continue)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.shoppingBag,
                                size: 12,
                                color: isDark ? AppColors.slate400 : AppColors.slate500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${quantity(order.itemCount)} item',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '·',
                                  style: TextStyle(
                                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                LucideIcons.clock,
                                size: 12,
                                color: isDark ? AppColors.slate400 : AppColors.slate500,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  timeFormatted,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (preview != null && preview!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              preview!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.slate400 : AppColors.slate600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Hapus',
                      style: IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(5),
                        minimumSize: const Size(30, 30),
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFDC2626)),
                      onPressed: onDelete,
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        minimumSize: const Size(0, 30),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onResume,
                      icon: const Icon(LucideIcons.play, size: 12),
                      label: const Text(
                        'Lanjut',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


