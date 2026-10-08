import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../data/order_models.dart';
import '../orders_providers.dart';

BadgeTone orderTone(String status) => switch (status) {
      OrderStatuses.ready => BadgeTone.success,
      OrderStatuses.inProgress => BadgeTone.warning,
      OrderStatuses.cancelled => BadgeTone.danger,
      OrderStatuses.pickedUp => BadgeTone.muted,
      _ => BadgeTone.info,
    };

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(ordersQueryProvider);
    final notifier = ref.read(ordersQueryProvider.notifier);

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(OrderStrings.screenTitle),
        hint: OrderStrings.searchHint,
        initialSearch: query.search,
        onSearchChanged: (term) => notifier.set((search: term, status: query.status)),
      ),
      floatingActionButton: AppFloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.orderNew),
        icon: const Icon(AppIcons.plus),
        label: const Text(OrderStrings.newTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
            child: Row(
              children: [
                FilterDropdownPill<String>(
                  label: OrderStrings.statusFilter,
                  icon: AppIcons.clipboardList,
                  value: query.status,
                  items: const [
                    ('open', OrderStrings.statusOpen),
                    (OrderStatuses.ready, OrderStrings.statusReady),
                    (OrderStatuses.pickedUp, OrderStrings.statusDone),
                    (OrderStatuses.cancelled, OrderStrings.statusCancelled),
                    ('all', OrderStrings.statusAll),
                  ],
                  onChanged: (value) => notifier.set((search: query.search, status: value ?? 'open')),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<CustomerOrder>(
              value: ref.watch(ordersProvider),
              onLoadMore: () => ref.read(ordersProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(ordersProvider.future),
              padding: const EdgeInsets.only(bottom: AppSpacing.s96),
              empty: const EmptyState(icon: AppIcons.clipboardList, title: OrderStrings.empty, description: OrderStrings.emptyHint),
              itemBuilder: (context, order) => ListTile(
                onTap: () => context.push(AppRoutes.orderDetail(order.id)),
                leading: Icon(order.isService ? AppIcons.wrench : AppIcons.clipboardList),
                title: Text('${order.number} · ${order.customerName}'),
                subtitle: Text(
                  [
                    if (order.pickupAt != null) OrderStrings.pickup(dateTime(order.pickupAt!)),
                    OrderStrings.depositShort(rupiah(order.deposit)),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: StatusBadge(label: order.statusLabel.toUpperCase(), tone: orderTone(order.status)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
