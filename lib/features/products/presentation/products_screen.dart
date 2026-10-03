import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../pos/presentation/camera_scanner_screen.dart';
import '../products_providers.dart';
import 'product_widgets.dart';

const _sorts = {
  'name': 'Nama A-Z',
  '-name': 'Nama Z-A',
  'price': 'Harga termurah',
  '-price': 'Harga termahal',
  'stock': 'Stok paling sedikit',
  '-stock': 'Stok paling banyak',
  'sku': 'SKU',
};

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productsQueryProvider);
    final notifier = ref.read(productsQueryProvider.notifier);
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final canManage = ref.watch(currentUserProvider)?.canManageMasterData ?? false;

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text('Produk'),
        hint: 'Cari nama, SKU, atau barcode',
        initialSearch: query.search,
        onSearchChanged: (term) => notifier.set((search: term, categoryId: query.categoryId, status: query.status, sort: query.sort)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Urutkan',
            icon: const Icon(LucideIcons.arrowUpDown, size: 20),
            initialValue: query.sort,
            onSelected: (sort) => notifier.set((search: query.search, categoryId: query.categoryId, status: query.status, sort: sort)),
            itemBuilder: (_) => [for (final entry in _sorts.entries) PopupMenuItem(value: entry.key, child: Text(entry.value))],
          ),
          IconButton(
            tooltip: 'Cari dengan barcode',
            icon: const Icon(LucideIcons.scanBarcode, size: 20),
            onPressed: () async {
              final code = await CameraScannerScreen.open(context);
              if (code != null) {
                notifier.set((search: code, categoryId: null, status: null, sort: query.sort));
              }
            },
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/product/new'),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Produk'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterDropdownPill<String>(
                    label: 'Status',
                    icon: LucideIcons.badgeCheck,
                    value: query.status,
                    items: const [
                      (null, 'Semua Status'),
                      ('active', 'Aktif'),
                      ('inactive', 'Nonaktif'),
                      ('low', 'Stok Menipis'),
                    ],
                    onChanged: (status) => notifier.set((search: query.search, categoryId: query.categoryId, status: status, sort: query.sort)),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    FilterDropdownPill<int>(
                      label: 'Kategori',
                      icon: LucideIcons.tag,
                      value: query.categoryId,
                      items: [
                        (null, 'Semua Kategori'),
                        for (final category in categories) (category.id, category.name),
                      ],
                      onChanged: (id) => notifier.set((search: query.search, categoryId: id, status: query.status, sort: query.sort)),
                    ),
                  ],
                  if (query.status != null || query.categoryId != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => notifier.set((search: query.search, categoryId: null, status: null, sort: query.sort)),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.x, size: 13),
                            SizedBox(width: 4),
                            Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: PagedListView(
              value: ref.watch(productsProvider),
              skeleton: const ProductListSkeleton(),
              onLoadMore: () => ref.read(productsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(productsProvider.future),
              padding: const EdgeInsets.only(bottom: 96),
              empty: const EmptyState(icon: LucideIcons.package, title: 'Produk tidak ditemukan', description: 'Ubah kata kunci atau filter.'),
              itemBuilder: (context, product) => ProductTile(product: product, onTap: () => context.push('/product/${product.id}')),
            ),
          ),
        ],
      ),
    );
  }
}
