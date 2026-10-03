import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../shift/shift_controller.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../pos_providers.dart';
import 'camera_scanner_screen.dart';
import 'held_orders_sheet.dart';
import 'pos_actions.dart';
import 'widgets/category_chips.dart';
import 'widgets/product_card.dart';

class CatalogPanel extends ConsumerStatefulWidget {
  const CatalogPanel({super.key});

  @override
  ConsumerState<CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends ConsumerState<CatalogPanel> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _showSearch = false;

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
    _showSearch = false;
    ref.read(catalogQueryProvider.notifier).search('');
    if (mounted) setState(() {});
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
    final qty = input == null ? null : parseQuantity(input);

    if (qty != null && qty > 0 && mounted) {
      addToCart(context, ref, product, quantity: qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final cart = ref.watch(cartProvider);
    final heldCount = ref.watch(posConfigProvider).value?.heldOrdersCount ?? 0;
    final shift = ref.watch(currentShiftProvider).value;
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearching = _showSearch || _search.text.isNotEmpty;

    return Column(
      children: [
        // Top Cashier & Search Bar Header
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              // Top strip: Shift & Cashier identity + Quick Actions
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        unawaited(HapticFeedback.lightImpact());
                        context.push('/shift');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate900 : AppColors.slate100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.slate800 : AppColors.slate200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.emerald500,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                shift != null
                                    ? '#${shift.number} · ${user?.name.split(' ').first ?? 'Kasir'}'
                                    : 'Kasir',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Search toggle button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isSearching ? 'Tutup pencarian' : 'Cari produk',
                    icon: Icon(
                      isSearching ? LucideIcons.searchX : LucideIcons.search,
                      size: 20,
                      color: isSearching ? Theme.of(context).colorScheme.primary : null,
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      setState(() {
                        _showSearch = !isSearching;
                        if (!_showSearch) {
                          _clearSearch();
                        }
                      });
                    },
                  ),
                  // Held orders button with badge
                  Badge(
                    isLabelVisible: heldCount > 0,
                    label: Text('$heldCount'),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Transaksi tertunda',
                      icon: const Icon(LucideIcons.clock, size: 20),
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
                        HeldOrdersSheet.show(context);
                      },
                    ),
                  ),
                  // Camera barcode scanner
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Scan barcode',
                    icon: const Icon(LucideIcons.scanBarcode, size: 20),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      _scan();
                    },
                  ),
                  // Theme mode toggle
                  Consumer(
                    builder: (context, ref, _) {
                      final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: isDarkMode ? 'Mode terang' : 'Mode gelap',
                        icon: Icon(isDarkMode ? LucideIcons.sun : LucideIcons.moon, size: 20),
                        onPressed: () {
                          unawaited(HapticFeedback.lightImpact());
                          ref.read(themeModeProvider.notifier).toggle();
                        },
                      );
                    },
                  ),
                ],
              ),
              if (isSearching) ...[
                const SizedBox(height: 8),
                SearchField(
                  controller: _search,
                  dense: true,
                  autofocus: true,
                  hint: 'Cari nama produk, SKU, barcode...',
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                ),
              ],
            ],
          ),
        ),

        // Category filter chips
        const PosCategoryChips(),

        // Products Grid
        Expanded(
          child: AsyncView(
            value: catalog,
            onRetry: () => ref.invalidate(catalogProvider),
            loading: const PosCatalogSkeleton(),
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
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  // ignore: deprecated_member_use
                  cacheExtent: 600,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisExtent: 226,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: page.products.length + (page.loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= page.products.length) {
                      return const AppShimmer(
                        child: SkeletonBox(
                          height: 226,
                          borderRadius: 14,
                        ),
                      );
                    }
                    final product = page.products[index];
                    final inCart = cart.items
                        .where((item) => item.productId == product.id)
                        .map((item) => item.quantity)
                        .fold<double>(0, (a, b) => a + b);

                    return PosProductCard(
                      key: ValueKey('pos_product_${product.id}'),
                      product: product,
                      inCartQuantity: inCart,
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
