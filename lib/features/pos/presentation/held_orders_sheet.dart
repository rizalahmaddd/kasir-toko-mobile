import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

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
          title: const Text(PosStrings.replaceCartTitle),
          content: const Text(PosStrings.replaceCartContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(PosStrings.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(PosStrings.replaceCartConfirm)),
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
        showMessage(context, notices.isEmpty ? PosStrings.heldOrderResumed(resumed.label ?? PosStrings.heldOrderFallbackLabel) : notices.join('\n'));
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
        title: Text(PosStrings.deleteHeldOrderTitle(order.label ?? PosStrings.heldOrderFallbackLower)),
        content: const Text(PosStrings.deleteHeldOrderContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(PosStrings.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(PosStrings.delete),
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
      return PosStrings.relativeJustNow;
    } else if (diff.inMinutes < 60) {
      return PosStrings.relativeMinutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return PosStrings.relativeHoursAgo(diff.inHours);
    } else if (diff.inDays == 1) {
      return PosStrings.relativeYesterday;
    } else {
      return PosStrings.relativeDaysAgo(diff.inDays);
    }
  }

  static String? _extractCartPreview(Map<String, dynamic>? cart) {
    if (cart == null) return null;
    final items = (cart['items'] as List?) ?? const [];
    if (items.isEmpty) return null;
    final names = items
        .map((item) {
          final name = item['name'] ?? item['product_name'] ?? PosStrings.heldPreviewItemFallback;
          final qty = item['quantity'] ?? 1;
          return PosStrings.heldPreviewItem(quantity(qty), name);
        })
        .take(3)
        .join(', ');
    return items.length > 3 ? PosStrings.heldPreviewMore(names) : names;
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
            title: PosStrings.heldOrdersTitle,
            subtitle: list.isEmpty ? null : PosStrings.heldOrdersSaved(list.length),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: AppIcons.clock,
                    title: PosStrings.heldOrdersEmptyTitle,
                    description: PosStrings.heldOrdersEmptyDescription,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s20),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.s8),
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
    final label = order.label?.trim().isNotEmpty == true ? order.label! : PosStrings.heldOrderNumber(order.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
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
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onResume,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Line 1: Badge #ID + Title + Price
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.amber900.withValues(alpha: 0.4) : AppColors.amber100,
                        borderRadius: BorderRadius.circular(AppRadius.r6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(AppIcons.pause, size: AppSizes.s10, color: AppColors.amber600),
                          const SizedBox(width: AppSizes.s3),
                          Text(
                            PosStrings.heldOrderIdBadge(order.id),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.amber600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.tableLabel != null) ...[
                      const SizedBox(width: AppSizes.s6),
                      const Text(
                        PosStrings.openBillBadge,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.sky500),
                      ),
                    ],
                    const SizedBox(width: AppSizes.s8),
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
                    const SizedBox(width: AppSizes.s8),
                    Text(
                      rupiah(order.total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.s5),

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
                                AppIcons.shoppingBag,
                                size: AppSizes.s12,
                                color: isDark ? AppColors.slate400 : AppColors.slate500,
                              ),
                              const SizedBox(width: AppSizes.s4),
                              Text(
                                PosStrings.heldOrderItemCount(quantity(order.itemCount)),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                                child: Text(
                                  '·',
                                  style: TextStyle(
                                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                AppIcons.clock,
                                size: AppSizes.s12,
                                color: isDark ? AppColors.slate400 : AppColors.slate500,
                              ),
                              const SizedBox(width: AppSizes.s4),
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
                            const SizedBox(height: AppSizes.s3),
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
                    const SizedBox(width: AppSizes.s8),
                    IconButton(
                      tooltip: PosStrings.delete,
                      style: IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(AppSpacing.s5),
                        minimumSize: const Size(30, 30),
                      ),
                      icon: const Icon(AppIcons.trash2, size: AppSizes.s16, color: AppColors.red600),
                      onPressed: onDelete,
                    ),
                    const SizedBox(width: AppSizes.s4),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s0),
                        minimumSize: const Size(0, 30),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
                      ),
                      onPressed: onResume,
                      icon: const Icon(AppIcons.play, size: AppSizes.s12),
                      label: const Text(
                        PosStrings.heldOrderResumeButton,
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


