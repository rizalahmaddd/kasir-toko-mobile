import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/cart_controller.dart';
import '../../pos/pos_providers.dart';
import '../data/self_order_models.dart';
import '../data/self_order_repository.dart';

/// Kotak masuk pesanan QR di kasir mobile: terima ke open bill, proses bayar, verifikasi QRIS, tolak, dan tandai diantar.
class SelfOrdersSheet extends ConsumerStatefulWidget {
  const SelfOrdersSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const FractionallySizedBox(heightFactor: 0.9, child: SelfOrdersSheet()),
      );

  @override
  ConsumerState<SelfOrdersSheet> createState() => _SelfOrdersSheetState();
}

class _SelfOrdersSheetState extends ConsumerState<SelfOrdersSheet> {
  int? _busyId;

  Future<void> _run(SelfOrder order, Future<String> Function(SelfOrderRepository repository) action) async {
    if (_busyId != null) {
      return;
    }
    setState(() => _busyId = order.id);

    try {
      final message = await action(ref.read(selfOrderRepositoryProvider));
      ref
        ..invalidate(selfOrdersProvider)
        ..invalidate(posConfigProvider);
      if (mounted) {
        showMessage(context, message);
      }
    } on ApiException catch (error) {
      ref.invalidate(selfOrdersProvider);
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _pay(SelfOrder order) async {
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

    await _run(order, (repository) async {
      final cart = await repository.cart(order.id);
      final controller = ref.read(cartProvider.notifier)..loadSelfOrder(cart);
      await controller.syncWithServer();
      if (mounted) {
        Navigator.pop(context);
      }

      return SelfOrderStrings.loaded(order.label);
    });
  }

  Future<void> _cancel(SelfOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(SelfOrderStrings.cancelTitle),
        content: const Text(SelfOrderStrings.cancelContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(SelfOrderStrings.keep)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(SelfOrderStrings.cancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await _run(order, (repository) async {
      await repository.cancel(order.id);

      return SelfOrderStrings.cancelled(order.number);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(selfOrdersProvider);

    return AsyncView<List<SelfOrder>>(
      value: orders,
      onRetry: () => ref.invalidate(selfOrdersProvider),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(title: SelfOrderStrings.title, subtitle: list.isEmpty ? null : SelfOrderStrings.openCount(list.length)),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: AppIcons.qrCode, title: SelfOrderStrings.emptyTitle, description: SelfOrderStrings.emptyDescription)
                : RefreshIndicator(
                    onRefresh: () => ref.refresh(selfOrdersProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.s8),
                      itemBuilder: (context, index) => _card(context, list[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, SelfOrder order) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final muted = TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant);
    final busy = _busyId != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(SelfOrderStrings.header(order.label, order.customerName), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                const SizedBox(width: AppSizes.s8),
                Text(rupiah(order.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            Text([order.number, timeOnly(order.createdAt), ?order.customerPhone].join(' · '), style: muted),
            const SizedBox(height: AppSizes.s8),
            Wrap(
              spacing: AppSpacing.s6,
              runSpacing: AppSpacing.s6,
              children: [
                StatusBadge(
                  label: order.statusLabel.toUpperCase(),
                  tone: order.isReady ? BadgeTone.success : (order.isPending ? BadgeTone.warning : BadgeTone.info),
                ),
                StatusBadge(
                  label: SelfOrderStrings.payment(order.isQris, order.paymentLabel).toUpperCase(),
                  tone: switch (order.paymentStatus) {
                    'rejected' => BadgeTone.danger,
                    'pending_verification' => BadgeTone.warning,
                    _ => BadgeTone.muted,
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            for (final item in order.items)
              Text(
                [
                  '${quantity(item.quantity)}× ${item.name}',
                  if (item.modifiers.isNotEmpty) '(${item.modifiers.join(', ')})',
                  if (item.note != null && item.note!.isNotEmpty) '· ${item.note}',
                ].join(' '),
                style: const TextStyle(fontSize: 13),
              ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.s4),
              Text(SelfOrderStrings.note(order.notes!), style: muted),
            ],
            if (order.nextAction == SelfOrderActions.verify) ...[
              const SizedBox(height: AppSizes.s6),
              Text(SelfOrderStrings.checkMutation(rupiah(order.total)), style: TextStyle(fontSize: 12, color: colors.warning)),
            ],
            const SizedBox(height: AppSizes.s10),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (order.nextAction == SelfOrderActions.accept)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _run(order, (repository) async {
                              await repository.accept(order.id);

                              return SelfOrderStrings.accepted(order.label);
                            }),
                    child: const Text(SelfOrderStrings.accept),
                  ),
                if (order.nextAction == SelfOrderActions.pay) FilledButton(onPressed: busy ? null : () => _pay(order), child: const Text(SelfOrderStrings.pay)),
                if (order.nextAction == SelfOrderActions.verify) ...[
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _run(order, (repository) async => SelfOrderStrings.verified(order.number, await repository.verifyPayment(order.id))),
                    child: const Text(SelfOrderStrings.verify),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _run(order, (repository) async {
                              await repository.rejectPayment(order.id);

                              return SelfOrderStrings.paymentRejected;
                            }),
                    child: const Text(SelfOrderStrings.rejectPayment),
                  ),
                ],
                if (order.nextAction == SelfOrderActions.decide)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _run(order, (repository) async {
                              await repository.billAtCashier(order.id);

                              return SelfOrderStrings.billed(order.label);
                            }),
                    child: const Text(SelfOrderStrings.billAtCashier),
                  ),
                if (order.isReady)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _run(order, (repository) async {
                              await repository.served(order.id);

                              return SelfOrderStrings.served(order.label);
                            }),
                    child: Text(order.isDineIn ? SelfOrderStrings.delivered : SelfOrderStrings.pickedUp),
                  ),
                if (!order.isPaid)
                  TextButton(
                    onPressed: busy ? null : () => _cancel(order),
                    style: TextButton.styleFrom(foregroundColor: colors.danger),
                    child: Text(order.isPending ? SelfOrderStrings.reject : SelfOrderStrings.cancel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
