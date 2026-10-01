import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../data/pos_models.dart';
import '../pos_providers.dart';
import 'camera_scanner_screen.dart';
import 'held_orders_sheet.dart';
import 'pos_actions.dart';

class CatalogPanel extends ConsumerStatefulWidget {
  const CatalogPanel({super.key});

  @override
  ConsumerState<CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends ConsumerState<CatalogPanel> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(catalogProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => ref.read(catalogQueryProvider.notifier).search(value));
  }

  /// Enter in the search box treats the text as a typed barcode/SKU when there's an exact match.
  Future<void> _onSearchSubmitted(String value) async {
    final products = ref.read(catalogProvider).value?.products ?? const [];
    final term = value.trim();
    final exact = products.where((p) => p.barcode == term || p.sku == term).firstOrNull;

    if (exact != null) {
      addToCart(context, ref, exact);
      _clearSearch();
    } else if (products.length == 1) {
      addToCart(context, ref, products.first);
      _clearSearch();
    }
  }

  void _clearSearch() {
    _search.clear();
    ref.read(catalogQueryProvider.notifier).search('');
  }

  Future<void> _scan() async {
    final code = await CameraScannerScreen.open(context);
    if (code != null && mounted) {
      await addByCode(context, ref, code);
    }
  }

  Future<void> _addWithQuantity(Product product) async {
    final input = await promptText(
      context,
      title: product.name,
      label: 'Jumlah',
      suffix: product.unit,
      confirmLabel: 'Tambah',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    );
    final quantity = input == null ? null : parseQuantity(input);

    if (quantity != null && quantity > 0 && mounted) {
      addToCart(context, ref, product, quantity: quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final heldCount = ref.watch(posConfigProvider).value?.heldOrdersCount ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, SKU, atau barcode',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: ListenableBuilder(
                      listenable: _search,
                      builder: (context, _) => _search.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(tooltip: 'Hapus pencarian', icon: const Icon(LucideIcons.x, size: 18), onPressed: _clearSearch),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(tooltip: 'Scan barcode', icon: const Icon(LucideIcons.scanBarcode), onPressed: _scan),
              const SizedBox(width: 4),
              Badge(
                isLabelVisible: heldCount > 0,
                label: Text('$heldCount'),
                child: IconButton.outlined(
                  tooltip: 'Transaksi tertunda',
                  icon: const Icon(LucideIcons.clock),
                  onPressed: () => HeldOrdersSheet.show(context),
                ),
              ),
            ],
          ),
        ),
        const _CategoryChips(),
        const SizedBox(height: 4),
        Expanded(
          child: AsyncView(
            value: catalog,
            onRetry: () => ref.invalidate(catalogProvider),
            data: (page) {
              if (page.products.isEmpty) {
                return const EmptyState(
                  icon: LucideIcons.package,
                  title: 'Produk tidak ditemukan',
                  description: 'Coba kata kunci lain atau pilih kategori Semua.',
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.refresh(catalogProvider.future),
                child: GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisExtent: 128,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: page.products.length + (page.loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= page.products.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final product = page.products[index];
                    return _ProductCard(
                      product: product,
                      onTap: () => addToCart(context, ref, product),
                      onLongPress: () => _addWithQuantity(product),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(posCategoriesProvider).value ?? const [];
    final selected = ref.watch(catalogQueryProvider).categoryId;

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (id, name) in [(null, 'Semua'), ...categories.map((c) => (c.id, c.name))])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(name),
                selected: selected == id,
                showCheckmark: false,
                onSelected: (_) => ref.read(catalogQueryProvider.notifier).category(id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap, required this.onLongPress});

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          opacity: product.isOutOfStock ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox(width: 36, height: 36),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (product.sku != null)
                  Text(product.sku!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rupiah(product.price),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                      ),
                    ),
                    if (product.isOutOfStock)
                      const StatusBadge(label: 'Habis', tone: BadgeTone.danger)
                    else if (product.trackStock)
                      Text(
                        '${quantity(product.stock)} ${product.unit}',
                        style: theme.textTheme.labelSmall?.copyWith(color: product.isLowStock ? colors.warning : muted),
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
