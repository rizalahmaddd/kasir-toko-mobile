import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../pos/cart_controller.dart';
import '../catalog_snapshot.dart';
import '../offline_queue.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

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
        showMessage(context, OfflineStrings.productsSavedMessage(snapshot.products.length));
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
          ? OfflineStrings.syncResultMessage(sent, left)
          : (ref.read(serverReachableProvider) ? OfflineStrings.noSyncableTransactions : OfflineStrings.serverStillUnreachable),
      isError: sent == 0 && left > 0,
    );
  }

  Future<void> _openInCart(QueuedSale sale) async {
    if (!ref.read(cartProvider).isEmpty) {
      final ok = await confirmAction(
        context,
        title: OfflineStrings.replaceCartTitle,
        message: OfflineStrings.replaceCartMessage,
        confirmLabel: OfflineStrings.replaceCartConfirm,
      );
      if (!ok) {
        return;
      }
    }
    ref.read(cartProvider.notifier).load(sale.cart);
    ref.read(offlineQueueProvider.notifier).remove(sale.clientUuid);
    if (mounted) {
      context.go(AppRoutes.pos);
      showMessage(context, OfflineStrings.recheckCartMessage);
    }
  }

  Future<void> _delete(QueuedSale sale) async {
    final ok = await confirmAction(
      context,
      title: OfflineStrings.deleteOfflineSaleTitle,
      message: OfflineStrings.deleteOfflineSaleMessage(rupiah(sale.total)),
      confirmLabel: OfflineStrings.deleteConfirm,
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
      appBar: AppBar(title: const Text(OfflineStrings.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s32),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection Status Hero
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: reachable
                          ? AppColors.emerald500.withValues(alpha: 0.4)
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
                          color: (reachable ? AppColors.emerald500 : colors.warning).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.r12),
                        ),
                        child: Icon(
                          reachable ? AppIcons.cloudCheck : AppIcons.cloudOff,
                          size: AppSizes.s22,
                          color: reachable ? AppColors.emerald600 : colors.warning,
                        ),
                      ),
                      const SizedBox(width: AppSizes.s14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  reachable ? OfflineStrings.connected : OfflineStrings.notReachable,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(width: AppSizes.s6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s1_5),
                                  decoration: BoxDecoration(
                                    color: (reachable ? AppColors.emerald500 : colors.warning).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.r5),
                                  ),
                                  child: Text(
                                    reachable ? OfflineStrings.onlineBadge : OfflineStrings.offlineBadge,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: reachable ? AppColors.emerald600 : colors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.s3),
                            Text(
                              reachable ? OfflineStrings.connectedDescription : OfflineStrings.offlineDescription,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.s16),

                // Local Catalog Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        OfflineStrings.catalogHeader,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: AppSizes.s12),
                      InfoRow(OfflineStrings.productsStoredLabel, snapshot == null ? OfflineStrings.noProducts : thousands(snapshot.products.length), bold: true),
                      InfoRow(OfflineStrings.lastUpdatedLabel, snapshot == null ? '-' : dateTime(snapshot.updatedAt)),
                      const SizedBox(height: AppSizes.s4),
                      Text(
                        OfflineStrings.catalogAutoUpdateHint,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: AppSizes.s12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                        ),
                        onPressed: _downloading ? null : _download,
                        icon: _downloading
                            ? const SizedBox.square(dimension: AppSizes.s16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(AppIcons.download, size: AppSizes.s16),
                        label: const Text(OfflineStrings.refreshCatalogButton, style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.s20),

                Row(
                  children: [
                    Expanded(
                      child: SectionTitle(
                        OfflineStrings.queueHeader(queue.length),
                      ),
                    ),
                    if (queue.isNotEmpty)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                        ),
                        onPressed: sync.syncing ? null : () => _sync(includeFailed: true),
                        icon: sync.syncing
                            ? const SizedBox.square(dimension: AppSizes.s12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(AppIcons.send, size: AppSizes.s14),
                        label: const Text(OfflineStrings.sendAllButton, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (sync.lastSyncAt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s0, AppSpacing.s4, AppSpacing.s8),
                    child: Text(OfflineStrings.lastSyncAttempt(timeOnly(sync.lastSyncAt!)), style: TextStyle(color: muted, fontSize: 12)),
                  ),
                if (failed > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: colors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.circleAlert, size: AppSizes.s16, color: colors.danger),
                        const SizedBox(width: AppSizes.s8),
                        Expanded(
                          child: Text(
                            OfflineStrings.failedSalesMessage(failed),
                            style: TextStyle(color: colors.danger, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (queue.isEmpty)
                  const EmptyState(icon: AppIcons.circleCheck, title: OfflineStrings.allSentTitle, description: OfflineStrings.allSentDescription)
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
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isFailed
              ? colors.danger.withValues(alpha: 0.5)
              : (isDark ? AppColors.slate700 : AppColors.slate200),
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
                label: isFailed ? OfflineStrings.statusRejected : OfflineStrings.statusWaiting,
                tone: isFailed ? BadgeTone.danger : BadgeTone.warning,
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onSelected: (action) => action == 'cart' ? onOpenInCart() : onDelete(),
                itemBuilder: (_) => [
                  if (isFailed) const PopupMenuItem(value: 'cart', child: Text(OfflineStrings.openInCart)),
                  const PopupMenuItem(value: 'delete', child: Text(OfflineStrings.deleteTransaction)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s4),
          Text(
            [
              dateTime(sale.createdAt),
              OfflineStrings.itemsCount(quantity(sale.itemCount)),
              if (sale.customerName != null) sale.customerName!,
            ].join(' · '),
            style: TextStyle(color: muted, fontSize: 12),
          ),
          if (sale.error != null) ...[
            const SizedBox(height: AppSizes.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.r6),
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

/// Strip above every screen once signed in, while offline or while sales wait to be sent.
/// Offline, every list and detail shows the last copy kept on the device, so say so.
class OfflineBannerFrame extends ConsumerWidget {
  const OfflineBannerFrame({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider) != null;
    final reachable = ref.watch(serverReachableProvider);
    final waiting = ref.watch(myQueueProvider).length;
    final syncing = ref.watch(syncStateProvider).syncing;
    if (!signedIn || (reachable && waiting == 0)) {
      return child;
    }

    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final color = reachable ? colors.info : colors.warning;
    final text = [
      if (!reachable) OfflineStrings.bannerOffline,
      if (waiting > 0) syncing ? OfflineStrings.sendingTransactions(waiting) : OfflineStrings.waitingTransactions(waiting),
    ].join(' · ');
    final dark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Material(
            color: Color.alphaBlend(color.withValues(alpha: 0.16), theme.colorScheme.surface),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 6, 16, 6),
                child: Row(
                  children: [
                    Icon(reachable ? AppIcons.refreshCw : AppIcons.cloudOff, size: AppSizes.s15, color: color),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: Text(text, maxLines: 2, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ),
                    Icon(AppIcons.chevronRight, size: AppSizes.s15, color: color),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
      ],
    );
  }
}
