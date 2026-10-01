import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/widgets/common.dart';
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

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
          ChoiceChips<bool>(
            options: const [(null, 'Semua'), (true, 'Aktif'), (false, 'Nonaktif')],
            selected: query.isActive,
            onSelected: (value) => notifier.set((search: query.search, isActive: value)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedListView(
              value: ref.watch(customersProvider),
              onLoadMore: () => ref.read(customersProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(customersProvider.future),
              padding: const EdgeInsets.only(bottom: 96),
              empty: const EmptyState(icon: LucideIcons.users, title: 'Pelanggan tidak ditemukan'),
              itemBuilder: (context, customer) => ListTile(
                onTap: () => context.push('/customer/${customer.id}'),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (!customer.isActive) ...[const SizedBox(width: 6), const StatusBadge(label: 'Nonaktif')],
                  ],
                ),
                subtitle: Text([customer.code, ?customer.phone, ?customer.type].join(' · '), style: TextStyle(color: muted)),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
