import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../customers_providers.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(customersQueryProvider);
    final notifier = ref.read(customersQueryProvider.notifier);
    final canManage = ref.watch(currentUserProvider)?.canManageMasterData ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/customer/new'),
              icon: const Icon(LucideIcons.userPlus),
              label: const Text('Pelanggan'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(hint: 'Cari nama, kode, atau nomor HP', onChanged: (term) => notifier.set((search: term, isActive: query.isActive))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilterDropdownPill<bool>(
                  label: 'Status',
                  icon: LucideIcons.userCheck,
                  value: query.isActive,
                  items: const [
                    (null, 'Semua Pelanggan'),
                    (true, 'Pelanggan Aktif'),
                    (false, 'Pelanggan Nonaktif'),
                  ],
                  onChanged: (value) => notifier.set((search: query.search, isActive: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: PagedListView(
              value: ref.watch(customersProvider),
              onLoadMore: () => ref.read(customersProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(customersProvider.future),
              padding: const EdgeInsets.only(bottom: 96),
              empty: const EmptyState(icon: LucideIcons.users, title: 'Pelanggan tidak ditemukan'),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/customer/${customer.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                            const SizedBox(width: 6),
                            const StatusBadge(label: 'Nonaktif', tone: BadgeTone.muted),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
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
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
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
                                Icon(LucideIcons.phone, size: 11, color: muted),
                                const SizedBox(width: 3),
                                Text(customer.phone!, style: TextStyle(fontSize: 12, color: muted)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
