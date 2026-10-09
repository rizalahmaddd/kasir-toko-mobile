import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../customers_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(customersQueryProvider);
    final notifier = ref.read(customersQueryProvider.notifier);
    final canManage = ref.watch(currentUserProvider)?.canManageMasterData ?? false;

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(CustomerStrings.screenTitle),
        hint: CustomerStrings.searchHint,
        initialSearch: query.search,
        onSearchChanged: (term) => notifier.set((search: term, isActive: query.isActive)),
      ),
      floatingActionButton: canManage
          ? AppFloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.customerNew),
              icon: const Icon(AppIcons.userPlus),
              label: const Text(CustomerStrings.screenTitle),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
            child: Row(
              children: [
                FilterDropdownPill<bool>(
                  label: CustomerStrings.statusFilterLabel,
                  icon: AppIcons.userCheck,
                  value: query.isActive,
                  items: const [
                    (null, CustomerStrings.allCustomers),
                    (true, CustomerStrings.activeCustomers),
                    (false, CustomerStrings.inactiveCustomers),
                  ],
                  onChanged: (value) => notifier.set((search: query.search, isActive: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s2),
          Expanded(
            child: PagedListView(
              value: ref.watch(customersProvider),
              onLoadMore: () => ref.read(customersProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(customersProvider.future),
              padding: const EdgeInsets.only(bottom: AppSpacing.s96),
              empty: const EmptyState(icon: AppIcons.users, title: CustomerStrings.noCustomersFound),
              itemBuilder: (context, customer) => _CustomerCard(customer: customer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final dynamic customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final initial = customer.name.isEmpty ? '?' : customer.name[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: () => context.push(AppRoutes.customerDetail(customer.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.blue900.withValues(alpha: 0.4) : AppColors.blue100,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          if (!customer.isActive) ...[
                            const SizedBox(width: AppSizes.s6),
                            const StatusBadge(label: CustomerStrings.inactive, tone: BadgeTone.muted),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSizes.s3),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            customer.code,
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (customer.type != null) ...[
                            Text('·', style: TextStyle(color: muted, fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: AppSpacing.s1),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.slate700 : AppColors.slate100,
                                borderRadius: BorderRadius.circular(AppRadius.r4),
                              ),
                              child: Text(
                                customer.type!,
                                style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                            Text('·', style: TextStyle(color: muted, fontSize: 12)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.phone, size: AppSizes.s11, color: muted),
                                const SizedBox(width: AppSizes.s3),
                                Text(customer.phone!, style: TextStyle(fontSize: 12, color: muted)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
