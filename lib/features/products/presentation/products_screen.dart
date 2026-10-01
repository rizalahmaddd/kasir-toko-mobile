import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/paging/paged.dart';
import '../../../core/widgets/common.dart';
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
      appBar: AppBar(
        title: const Text('Produk'),
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(
              initialValue: query.search,
              hint: 'Cari nama, SKU, atau barcode',
              onChanged: (term) => notifier.set((search: term, categoryId: query.categoryId, status: query.status, sort: query.sort)),
            ),
          ),
          ChoiceChips<String>(
            options: const [(null, 'Semua'), ('active', 'Aktif'), ('inactive', 'Nonaktif'), ('low', 'Stok menipis')],
            selected: query.status,
            onSelected: (status) => notifier.set((search: query.search, categoryId: query.categoryId, status: status, sort: query.sort)),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 6),
            ChoiceChips<int>(
              options: [(null, 'Semua kategori'), for (final category in categories) (category.id, category.name)],
              selected: query.categoryId,
              onSelected: (id) => notifier.set((search: query.search, categoryId: id, status: query.status, sort: query.sort)),
            ),
          ],
          const SizedBox(height: 4),
          Expanded(
            child: PagedListView(
              value: ref.watch(productsProvider),
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
