import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../pos/pos_providers.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';
import '../orders_providers.dart';
import 'order_actions.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<CustomerOrder> Function() action, String done) async {
    try {
      await action();
      ref
        ..invalidate(orderProvider(orderId))
        ..invalidate(ordersProvider);
      if (context.mounted) {
        showMessage(context, done);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final methods = ref.read(posConfigProvider).value?.paymentMethods ?? const [];
    final amount = TextEditingController();
    var method = methods.isEmpty ? 'cash' : methods.first.value;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(OrderStrings.payTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: OrderStrings.amount, prefixText: 'Rp '),
              ),
              const SizedBox(height: AppSizes.s12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: OrderStrings.method),
                items: [for (final option in methods) DropdownMenuItem(value: option.value, child: Text(option.label))],
                onChanged: (value) => setState(() => method = value ?? method),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(OrderStrings.back)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(OrderStrings.saveDeposit)),
          ],
        ),
      ),
    );

    final value = int.tryParse(amount.text) ?? 0;
    amount.dispose();
    if (confirmed == true && value > 0 && context.mounted) {
      await _run(context, ref, () => ref.read(ordersRepositoryProvider).pay(orderId, amount: value, method: method), OrderStrings.depositSaved);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, CustomerOrder order) async {
    final reason = TextEditingController();
    var refund = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(OrderStrings.cancelTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: reason, autofocus: true, decoration: const InputDecoration(labelText: OrderStrings.cancelReason)),
              if (order.deposit > 0)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: refund,
                  onChanged: (value) => setState(() => refund = value ?? true),
                  title: Text(OrderStrings.refund(rupiah(order.deposit))),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(OrderStrings.back)),
            FilledButton(onPressed: () => Navigator.pop(context, reason.text.trim().isNotEmpty), child: const Text(OrderStrings.cancelTitle)),
          ],
        ),
      ),
    );

    final text = reason.text.trim();
    reason.dispose();
    if (confirmed == true && context.mounted) {
      await _run(context, ref, () => ref.read(ordersRepositoryProvider).cancel(orderId, reason: text, refund: refund), OrderStrings.cancelled);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderProvider(orderId));
    final canSell = ref.watch(currentUserProvider)?.canSell ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(value.value?.number ?? OrderStrings.screenTitle)),
      body: AsyncView<CustomerOrder>(
        value: value,
        onRetry: () => ref.invalidate(orderProvider(orderId)),
        data: (order) => MaxWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Wrap(spacing: AppSpacing.s8, children: [StatusBadge(label: order.statusLabel.toUpperCase(), tone: orderTone(order.status))]),
              const SectionTitle(OrderStrings.customer),
              InfoRow(OrderStrings.customer, order.customerName),
              if (order.customerPhone != null) InfoRow('HP', order.customerPhone!),
              if (order.pickupAt != null) InfoRow(order.isService ? OrderStrings.estimatedDone : OrderStrings.pickupLabel, dateTime(order.pickupAt!)),
              if (order.isService) ...[
                const SectionTitle(OrderStrings.device),
                InfoRow(OrderStrings.device, order.device ?? '-'),
                if (order.deviceSerial != null) InfoRow('IMEI/SN', order.deviceSerial!),
                InfoRow(OrderStrings.complaint, order.complaint ?? '-'),
              ],
              if (order.notes != null) InfoRow(OrderStrings.notes, order.notes!),
              if (order.items.isNotEmpty) ...[
                const SectionTitle(OrderStrings.items),
                for (final item in order.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: item.note == null ? null : Text(item.note!),
                    trailing: Text('${quantity(item.quantity)} × ${rupiah(item.price)}'),
                  ),
              ],
              const SectionTitle(OrderStrings.payment),
              InfoRow(OrderStrings.estimate, rupiah(order.estimatedTotal)),
              InfoRow(OrderStrings.deposit, rupiah(order.deposit)),
              InfoRow(OrderStrings.remaining, rupiah(order.remaining), bold: true),
              const SizedBox(height: AppSizes.s24),
              if (order.isOpen) ...[
                if (canSell)
                  FilledButton.icon(
                    onPressed: () => settleOrderAtCashier(context, ref, orderId),
                    icon: const Icon(AppIcons.banknote),
                    label: const Text(OrderStrings.settle),
                  ),
                const SizedBox(height: AppSizes.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  children: [
                    for (final status in OrderStatuses.editable)
                      ChoiceChip(
                        label: Text(OrderStrings.statusLabels[status]!),
                        selected: order.status == status,
                        onSelected: (_) => _run(context, ref, () => ref.read(ordersRepositoryProvider).setStatus(orderId, status), OrderStrings.statusChanged),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.s8),
                OutlinedButton.icon(onPressed: () => _pay(context, ref), icon: const Icon(AppIcons.handCoins), label: const Text(OrderStrings.payTitle)),
                const SizedBox(height: AppSizes.s8),
                OutlinedButton.icon(onPressed: () => _cancel(context, ref, order), icon: const Icon(AppIcons.ban), label: const Text(OrderStrings.cancelTitle)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
