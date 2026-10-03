import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
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
import 'widgets/cart_line_edit_sheet.dart';
import 'widgets/product_card.dart';
import 'widgets/product_list_tile.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';

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
  bool _showDensitySlider = false;

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
    _debounce = Timer(AppDurations.milliseconds350, () => ref.read(catalogQueryProvider.notifier).search(value));
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
      label: PosStrings.quantityFieldLabel,
      suffix: product.unit,
      confirmLabel: PosStrings.addConfirm,
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
    final density = ref.watch(posCatalogDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearching = _showSearch || _search.text.isNotEmpty;

    final screenWidth = context.screenWidth;
    final estimatedPanelWidth = context.isWide
        ? (screenWidth - (screenWidth >= 1200 ? 421 : 361))
        : screenWidth;
    final sliderConfig = density.computeConfig(estimatedPanelWidth);

    return Column(
      children: [
        // Top Cashier & Search Bar Header
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s10, AppSpacing.s12, AppSpacing.s6),
          child: Column(
            children: [
              // Top strip: Shift & Cashier identity + Quick Actions
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.r20),
                      onTap: () {
                        unawaited(HapticFeedback.lightImpact());
                        context.push(AppRoutes.shift);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate900 : AppColors.slate100,
                          borderRadius: BorderRadius.circular(AppRadius.r20),
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
                            const SizedBox(width: AppSizes.s6),
                            Flexible(
                              child: Text(
                                shift != null
                                    ? PosStrings.shiftCashierLabel(shift.number, user?.name.split(' ').first ?? PosStrings.cashierFallback)
                                    : PosStrings.cashierFallback,
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
                    tooltip: isSearching ? PosStrings.closeSearchTooltip : PosStrings.openSearchTooltip,
                    icon: Icon(
                      isSearching ? AppIcons.searchX : AppIcons.search,
                      size: AppSizes.s20,
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
                      tooltip: PosStrings.heldOrdersTooltip,
                      icon: const Icon(AppIcons.clock, size: AppSizes.s20),
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
                        HeldOrdersSheet.show(context);
                      },
                    ),
                  ),
                  // Catalog density slider toggle button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: PosStrings.densitySliderTooltip,
                    icon: Icon(
                      AppIcons.slidersHorizontal,
                      size: AppSizes.s20,
                      color: _showDensitySlider ? Theme.of(context).colorScheme.primary : null,
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      setState(() {
                        _showDensitySlider = !_showDensitySlider;
                      });
                    },
                  ),
                  // Camera barcode scanner
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: PosStrings.scanBarcodeTooltip,
                    icon: const Icon(AppIcons.scanBarcode, size: AppSizes.s20),
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
                        tooltip: isDarkMode ? PosStrings.lightModeTooltip : PosStrings.darkModeTooltip,
                        icon: Icon(isDarkMode ? AppIcons.sun : AppIcons.moon, size: AppSizes.s20),
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
                const SizedBox(height: AppSizes.s8),
                SearchField(
                  controller: _search,
                  dense: true,
                  autofocus: true,
                  hint: PosStrings.searchHint,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                ),
              ],
              if (_showDensitySlider) ...[
                const SizedBox(height: AppSizes.s8),
                _DensitySliderBar(
                  density: density,
                  columns: sliderConfig.columns,
                  onChanged: (newDensity) {
                    ref.read(posCatalogDensityProvider.notifier).setDensity(newDensity);
                  },
                  onClose: () => setState(() => _showDensitySlider = false),
                ),
              ],
            ],
          ),
        ),

        // Category filter chips
        const PosCategoryChips(),

        // Products Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final activeWidth = constraints.maxWidth;
              final gridConfig = density.computeConfig(activeWidth);
              final isList = density == PosCatalogDensity.list;
              final spacing = isList ? 8.0 : (density == PosCatalogDensity.compact ? 8.0 : 10.0);

              final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridConfig.columns,
                mainAxisExtent: gridConfig.mainAxisExtent,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              );

              return AsyncView(
                value: catalog,
                onRetry: () => ref.invalidate(catalogProvider),
                loading: PosCatalogSkeleton(
                  isList: isList,
                  gridDelegate: gridDelegate,
                  cardHeight: gridConfig.mainAxisExtent,
                  photoHeight: gridConfig.photoHeight,
                ),
                data: (page) {
                  if (page.products.isEmpty) {
                    return const EmptyState(
                      icon: AppIcons.package,
                      title: PosStrings.productNotFoundTitle,
                      description: PosStrings.productNotFoundDescription,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(catalogProvider.future),
                    child: GridView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      // ignore: deprecated_member_use
                      cacheExtent: 600,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s4, AppSpacing.s12, AppSpacing.s16),
                      gridDelegate: gridDelegate,
                      itemCount: page.products.length + (page.loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= page.products.length) {
                          return AppShimmer(
                            child: SkeletonBox(
                              height: gridConfig.mainAxisExtent,
                              borderRadius: isList ? 12.0 : 14.0,
                            ),
                          );
                        }
                        final product = page.products[index];
                        final inCartItems = cart.items.where((item) => item.productId == product.id).toList();
                        final inCart = inCartItems.map((item) => item.quantity).fold<double>(0, (a, b) => a + b);
                        final firstCartItem = inCartItems.firstOrNull;

                        if (isList) {
                          return PosProductListTile(
                            key: ValueKey('pos_product_${product.id}'),
                            product: product,
                            inCartQuantity: inCart,
                            onTap: () => addToCart(context, ref, product),
                            onDecrement: inCart > 0 ? () => decrementFromCart(context, ref, product) : null,
                            onEditQuantity: inCart > 0 && firstCartItem != null
                                ? () => CartLineEditSheet.show(
                                      context,
                                      firstCartItem,
                                      canDiscount: ref.read(posConfigProvider).value?.canDiscount ?? false,
                                    )
                                : null,
                            onLongPress: () {
                              if (firstCartItem != null) {
                                CartLineEditSheet.show(
                                  context,
                                  firstCartItem,
                                  canDiscount: ref.read(posConfigProvider).value?.canDiscount ?? false,
                                );
                              } else {
                                _addWithQuantity(product);
                              }
                            },
                          );
                        }

                        return PosProductCard(
                          key: ValueKey('pos_product_${product.id}'),
                          product: product,
                          inCartQuantity: inCart,
                          isLarge: gridConfig.isLarge,
                          customPhotoHeight: gridConfig.photoHeight,
                          onTap: () => addToCart(context, ref, product),
                          onDecrement: inCart > 0 ? () => decrementFromCart(context, ref, product) : null,
                          onEditQuantity: inCart > 0 && firstCartItem != null
                              ? () => CartLineEditSheet.show(
                                    context,
                                    firstCartItem,
                                    canDiscount: ref.read(posConfigProvider).value?.canDiscount ?? false,
                                  )
                              : null,
                          onLongPress: () {
                            if (firstCartItem != null) {
                              CartLineEditSheet.show(
                                context,
                                firstCartItem,
                                canDiscount: ref.read(posConfigProvider).value?.canDiscount ?? false,
                              );
                            } else {
                              _addWithQuantity(product);
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DensitySliderBar extends StatelessWidget {
  const _DensitySliderBar({
    required this.density,
    required this.columns,
    required this.onChanged,
    required this.onClose,
  });

  final PosCatalogDensity density;
  final int columns;
  final ValueChanged<PosCatalogDensity> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s8, AppSpacing.s12, AppSpacing.s10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.slate50,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.slidersHorizontal,
                size: AppSizes.s16,
                color: primary,
              ),
              const SizedBox(width: AppSizes.s8),
              Text(
                PosStrings.densityColumnsInfo(density.label, columns),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(AppIcons.x, size: AppSizes.s16, color: muted),
                onPressed: () {
                  unawaited(HapticFeedback.lightImpact());
                  onClose();
                },
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primary,
              inactiveTrackColor: isDark ? AppColors.slate700 : AppColors.slate300,
              thumbColor: primary,
              overlayColor: primary.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
              activeTickMarkColor: Colors.white,
              inactiveTickMarkColor: isDark ? AppColors.slate600 : AppColors.slate400,
            ),
            child: Slider(
              value: density.value.toDouble(),
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: (val) {
                final newDensity = PosCatalogDensity.fromValue(val.round());
                if (newDensity != density) {
                  unawaited(HapticFeedback.selectionClick());
                  onChanged(newDensity);
                }
              },
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const trackPadding = 16.0;
              final trackWidth = constraints.maxWidth - (trackPadding * 2);
              final step = trackWidth / 3;

              final x1 = trackPadding + step;
              final x2 = trackPadding + (step * 2);

              return SizedBox(
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Paling kiri: Daftar (rata kiri tepat di awal track)
                    Positioned(
                      left: trackPadding,
                      top: 0,
                      bottom: 0,
                      child: _DensityLabel(
                        label: PosStrings.densityList,
                        isSelected: density == PosCatalogDensity.list,
                        alignment: Alignment.centerLeft,
                        textAlign: TextAlign.left,
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          onChanged(PosCatalogDensity.list);
                        },
                      ),
                    ),
                    // Di antara kiri-kanan: Ringkas (center tepat di Tick 1)
                    Positioned(
                      left: x1 - 50,
                      width: 100,
                      top: 0,
                      bottom: 0,
                      child: _DensityLabel(
                        label: PosStrings.densityCompact,
                        isSelected: density == PosCatalogDensity.compact,
                        alignment: Alignment.center,
                        textAlign: TextAlign.center,
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          onChanged(PosCatalogDensity.compact);
                        },
                      ),
                    ),
                    // Di antara kiri-kanan: Standar (center tepat di Tick 2)
                    Positioned(
                      left: x2 - 50,
                      width: 100,
                      top: 0,
                      bottom: 0,
                      child: _DensityLabel(
                        label: PosStrings.densityStandard,
                        isSelected: density == PosCatalogDensity.standard,
                        alignment: Alignment.center,
                        textAlign: TextAlign.center,
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          onChanged(PosCatalogDensity.standard);
                        },
                      ),
                    ),
                    // Paling kanan: Besar (rata kanan tepat di akhir track)
                    Positioned(
                      right: trackPadding,
                      top: 0,
                      bottom: 0,
                      child: _DensityLabel(
                        label: PosStrings.densityLarge,
                        isSelected: density == PosCatalogDensity.large,
                        alignment: Alignment.centerRight,
                        textAlign: TextAlign.right,
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          onChanged(PosCatalogDensity.large);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DensityLabel extends StatelessWidget {
  const _DensityLabel({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.alignment = Alignment.center,
    this.textAlign = TextAlign.center,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Alignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.r6),
        onTap: onTap,
        child: Container(
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            label,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primary : muted,
            ),
          ),
        ),
      ),
    );
  }
}
