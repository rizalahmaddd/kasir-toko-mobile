import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../receivables/receivables.dart';
import '../../sales/presentation/sale_tile.dart';
import '../customers_providers.dart';
import '../data/customers_repository.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(customerId));
    final user = ref.watch(currentUserProvider);
    final canManage = user?.canManageMasterData ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.value?.name ?? CustomerStrings.screenTitle),
        actions: [
          if (canManage && customer.value != null) ...[
            IconButton(tooltip: CustomerStrings.editTooltip, icon: const Icon(AppIcons.pencil, size: AppSizes.s20), onPressed: () => context.push(AppRoutes.customerEdit(customerId))),
            IconButton(tooltip: CustomerStrings.deleteTooltip, icon: const Icon(AppIcons.trash2, size: AppSizes.s20), onPressed: () => _delete(context, ref, customer.value!)),
          ],
        ],
      ),
      body: AsyncView(
        value: customer,
        onRetry: () => ref.invalidate(customerProvider(customerId)),
        data: (customer) {
          final wa = whatsappNumber(customer.phone);

          return RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.read(customerProvider(customerId).notifier).refresh(),
              ref.read(customerSalesProvider(customerId).notifier).refresh(),
              ref.read(customerReceivablesProvider(customerId).notifier).refresh(),
            ]),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                MaxWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.slate800
                              : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.r16),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.slate700
                                : AppColors.slate200,
                          ),
                          boxShadow: [
                            if (Theme.of(context).brightness != Brightness.dark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.blue900.withValues(alpha: 0.4)
                                        : AppColors.blue100,
                                    borderRadius: BorderRadius.circular(AppRadius.r14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.blue600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.s14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: AppSizes.s6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s7, vertical: AppSpacing.s2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? AppColors.slate700
                                                  : AppColors.slate100,
                                              borderRadius: BorderRadius.circular(AppRadius.r6),
                                            ),
                                            child: Text(
                                              customer.code,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          if (customer.type != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s7, vertical: AppSpacing.s2),
                                              decoration: BoxDecoration(
                                                color: AppColors.teal600.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(AppRadius.r6),
                                              ),
                                              child: Text(
                                                customer.type!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.teal600,
                                                ),
                                              ),
                                            ),
                                          StatusBadge(
                                            label: customer.isActive ? CustomerStrings.active : CustomerStrings.inactive,
                                            tone: customer.isActive ? BadgeTone.success : BadgeTone.muted,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (customer.phone != null) ...[
                              const SizedBox(height: AppSizes.s16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                                      ),
                                      onPressed: () => openExternal(context, Uri(scheme: 'tel', path: customer.phone)),
                                      icon: const Icon(AppIcons.phone, size: AppSizes.s16),
                                      label: const Text(CustomerStrings.teleponButton, style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  if (wa != null) ...[
                                    const SizedBox(width: AppSizes.s8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
                                          backgroundColor: AppColors.emerald500.withValues(alpha: 0.15),
                                          foregroundColor: AppColors.emerald600,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                                        ),
                                        onPressed: () => openExternal(context, Uri.parse('https://wa.me/$wa'), failure: CustomerStrings.whatsappOpenFailed),
                                        icon: const Icon(AppIcons.messageCircle, size: AppSizes.s16),
                                        label: const Text(CustomerStrings.whatsappButton, style: TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
                              child: Divider(height: 1),
                            ),
                            InfoRow(CustomerStrings.phoneInfoLabel, customer.phone ?? '-'),
                            if (customer.contactPerson != null) InfoRow(CustomerStrings.contactPersonInfoLabel, customer.contactPerson!),
                            if (customer.email != null) InfoRow(CustomerStrings.emailInfoLabel, customer.email!),
                            if (customer.address != null) InfoRow(CustomerStrings.addressInfoLabel, customer.address!),
                            if (customer.npwp != null) InfoRow(CustomerStrings.npwpInfoLabel, customer.npwp!),
                            InfoRow(
                              CustomerStrings.paymentTermInfoLabel,
                              customer.paymentTermDays == 0 ? CustomerStrings.cashPayment : CustomerStrings.paymentTermDays(customer.paymentTermDays),
                            ),
                            InfoRow(CustomerStrings.creditLimitLabel, customer.creditLimit == null ? CustomerStrings.noCreditLimit : rupiah(customer.creditLimit!)),
                          ],
                        ),
                      ),
                      if (user?.canViewSales ?? false) _CustomerSales(customerId: customerId),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Customer customer) async {
    final ok = await confirmAction(
      context,
      title: CustomerStrings.deleteDialogTitle,
      message: CustomerStrings.deleteCustomerMessage(customer.name),
      confirmLabel: CustomerStrings.deleteConfirmButton,
      danger: true,
    );
    if (!ok || !context.mounted) {
      return;
    }

    try {
      await ref.read(customersRepositoryProvider).delete(customer.id);
      ref.read(customersProvider.notifier).remove((item) => item.id == customer.id);
      ref.read(dataChangesProvider).after({DataChange.customers});
      if (context.mounted) {
        context.pop();
        showMessage(context, CustomerStrings.customerDeleted(customer.name));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }
}

class _CustomerSales extends ConsumerWidget {
  const _CustomerSales({required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(customerSalesProvider(customerId));
    final colors = StatusColors.of(context);

    return switch (sales) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.s12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatTile(label: CustomerStrings.yearlySpendLabel, value: rupiah(value.total), caption: CustomerStrings.transactionCount(value.count)),
                ),
                const SizedBox(width: AppSizes.s8),
                if (ref.watch(currentUserProvider)?.canManageReceivables ?? false)
                  Expanded(
                    child: StatTile(
                      label: CustomerStrings.unpaidReceivablesLabel,
                      value: rupiah(ref.watch(customerReceivablesProvider(customerId)).value?.fold<int>(0, (sum, sale) => sum + sale.dueAmount) ?? 0),
                      color: colors.warning,
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle(CustomerStrings.recentTransactionsTitle),
          if (value.items.isEmpty)
            Text(CustomerStrings.noTransactionsLastYear, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            Column(
              children: [
                for (final sale in value.items.take(15))
                  SaleTile(sale: sale, margin: const EdgeInsets.only(bottom: AppSpacing.s8)),
              ],
            ),
        ],
      ),
      AsyncError(:final error) => Padding(padding: const EdgeInsets.only(top: AppSpacing.s16), child: Text(errorMessage(error))),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: SalesListSkeleton(itemCount: 3, showSummary: false, shrinkWrap: true),
      ),
    };
  }
}
