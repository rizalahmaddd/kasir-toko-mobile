import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../pos/presentation/camera_scanner_screen.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import '../products_providers.dart';
import 'product_widgets.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

const _units = ProductStrings.unitOptions;

/// Loads the product first when editing, so the form always starts from server values.
class ProductFormScreen extends ConsumerWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (productId == null) {
      return const _ProductForm();
    }

    final product = ref.watch(productDetailProvider(productId!));

    return product.when(
      data: (product) => _ProductForm(product: product),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text(ProductStrings.titleEditProduct)),
        body: ErrorState(
          error: error,
          onRetry: () => ref.invalidate(productDetailProvider(productId!)),
        ),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text(ProductStrings.titleLoadingProduct)),
        body: const DefaultListSkeleton(itemCount: 6),
      ),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.product});

  final ProductRecord? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final ProductRecord? _p = widget.product;
  late final _name = TextEditingController(text: _p?.name);
  late final _sku = TextEditingController(text: _p?.sku);
  late final _barcode = TextEditingController(text: _p?.barcode);
  late final _unit = TextEditingController(text: _p?.unit ?? 'pcs');
  late final _price = TextEditingController(text: _p == null ? '' : thousands(_p.price));
  late final _cost = TextEditingController(text: _p == null || _p.costPrice == 0 ? '' : thousands(_p.costPrice));
  late final _stock = TextEditingController();
  late final _minStock = TextEditingController(text: _p == null ? '' : editableQuantity(_p.minStock));
  late int? _categoryId = _p?.category?.id;
  late bool _trackStock = _p?.trackStock ?? true;
  late bool _isActive = _p?.isActive ?? true;
  bool _busy = false;
  ApiException? _error;

  bool get _isNew => _p == null;

  @override
  void initState() {
    super.initState();
    _price.addListener(_onFieldChanged);
    _cost.addListener(_onFieldChanged);
    _name.addListener(_onFieldChanged);
    _unit.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _price.removeListener(_onFieldChanged);
    _cost.removeListener(_onFieldChanged);
    _name.removeListener(_onFieldChanged);
    _unit.removeListener(_onFieldChanged);
    for (final controller in [_name, _sku, _barcode, _unit, _price, _cost, _stock, _minStock]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _clean(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final sellingPrice = parseRupiah(_price.text);
    if (sellingPrice <= 0) {
      showMessage(context, ProductStrings.validationSellingPriceRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final input = ProductInput(
      categoryId: _categoryId,
      sku: _clean(_sku)?.toUpperCase(),
      barcode: _clean(_barcode),
      name: _name.text.trim(),
      unit: _unit.text.trim(),
      costPrice: _cost.text.isEmpty ? null : parseRupiah(_cost.text),
      price: sellingPrice,
      trackStock: _trackStock,
      stock: _isNew && _trackStock ? parseQuantity(_stock.text) : null,
      minStock: _trackStock ? parseQuantity(_minStock.text) : null,
      isActive: _isActive,
    );

    try {
      final saved = await ref.read(productsRepositoryProvider).saveProduct(input, id: _p?.id);
      ref.read(dataChangesProvider).after({DataChange.products});
      if (mounted) {
        showMessage(context, _isNew ? ProductStrings.productAddedMessage(saved.name) : ProductStrings.messageProductUpdated);
        if (_isNew) {
          context.pushReplacement(AppRoutes.productDetail(saved.id));
        } else {
          context.pop();
        }
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = StatusColors.of(context);
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;
    final unfocus = FocusManager.instance.primaryFocus?.unfocus;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? ProductStrings.titleNewProduct : ProductStrings.titleEditProduct),
        centerTitle: false,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unfocus?.call(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s24),
            children: [
              MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header / Summary card
                    if (!_isNew)
                      _buildExistingProductBanner(context, isDark)
                    else
                      _buildNewProductBanner(context, isDark),

                    const SizedBox(height: AppSizes.s16),

                    // Card 1: Informasi Produk
                    _FormSectionCard(
                      title: ProductStrings.sectionProductInfo,
                      subtitle: ProductStrings.sectionProductInfoSubtitle,
                      icon: AppIcons.package,
                      iconColor: theme.colorScheme.primary,
                      children: [
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: ProductStrings.fieldProductName,
                            hintText: ProductStrings.hintProductName,
                            prefixIcon: const Icon(AppIcons.tag, size: AppSizes.s18),
                            errorText: _error?.fieldError('name'),
                            suffixIcon: _name.text.isNotEmpty
                                ? IconButton(
                                    tooltip: ProductStrings.tooltipClearText,
                                    icon: const Icon(AppIcons.x, size: AppSizes.s16),
                                    onPressed: () {
                                      _name.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty ? ProductStrings.validationProductNameRequired : null,
                        ),
                        const SizedBox(height: AppSizes.s14),
                        DropdownButtonFormField<int?>(
                          initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: ProductStrings.labelCategory,
                            prefixIcon: const Icon(AppIcons.folder, size: AppSizes.s18),
                            errorText: _error?.fieldError('category_id'),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text(ProductStrings.categoryNoCategory)),
                            for (final category in categories) DropdownMenuItem(value: category.id, child: Text(category.name)),
                          ],
                          onChanged: (value) => setState(() => _categoryId = value),
                        ),
                        const SizedBox(height: AppSizes.s14),
                        TextFormField(
                          controller: _unit,
                          decoration: InputDecoration(
                            labelText: ProductStrings.fieldBaseUnit,
                            hintText: ProductStrings.hintBaseUnit,
                            prefixIcon: const Icon(AppIcons.scale, size: AppSizes.s18),
                            errorText: _error?.fieldError('unit'),
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty ? ProductStrings.validationUnitRequired : null,
                        ),
                        const SizedBox(height: AppSizes.s10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final unit in _units)
                              ChoiceChip(
                                label: Text(unit),
                                selected: _unit.text.trim().toLowerCase() == unit,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onSelected: (_) {
                                  setState(() {
                                    _unit.text = unit;
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.s16),

                    // Card 2: SKU & Barcode
                    _FormSectionCard(
                      title: ProductStrings.sectionBarcode,
                      subtitle: ProductStrings.sectionBarcodeSubtitle,
                      icon: AppIcons.scanLine,
                      iconColor: AppColors.sky500,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sku,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: ProductStrings.fieldSku,
                                  hintText: ProductStrings.hintSku,
                                  prefixIcon: const Icon(AppIcons.hash, size: AppSizes.s18),
                                  errorText: _error?.fieldError('sku'),
                                  helperText: ProductStrings.helperSku,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSizes.s12),
                            Expanded(
                              child: TextFormField(
                                controller: _barcode,
                                decoration: InputDecoration(
                                  labelText: ProductStrings.labelBarcode,
                                  hintText: ProductStrings.hintBarcode,
                                  prefixIcon: const Icon(AppIcons.barcode, size: AppSizes.s18),
                                  errorText: _error?.fieldError('barcode'),
                                  suffixIcon: IconButton(
                                    tooltip: ProductStrings.tooltipScanBarcodeCamera,
                                    icon: Container(
                                      padding: const EdgeInsets.all(AppSpacing.s6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(AppRadius.r8),
                                      ),
                                      child: Icon(AppIcons.scanBarcode, size: AppSizes.s16, color: theme.colorScheme.primary),
                                    ),
                                    onPressed: () async {
                                      final code = await CameraScannerScreen.open(context);
                                      if (code != null && code.isNotEmpty) {
                                        _barcode.text = code;
                                        if (mounted) setState(() {});
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.s16),

                    // Card 3: Penetapan Harga & Kalkulator Margin
                    _FormSectionCard(
                      title: ProductStrings.sectionPriceMargin,
                      subtitle: ProductStrings.sectionPriceMarginSubtitle,
                      icon: AppIcons.badgePercent,
                      iconColor: AppColors.emerald500,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: MoneyField(
                                controller: _price,
                                label: ProductStrings.fieldSellingPriceRequired,
                                errorText: _error?.fieldError('price'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: AppSizes.s12),
                            Expanded(
                              child: MoneyField(
                                controller: _cost,
                                label: ProductStrings.labelCostPrice,
                                errorText: _error?.fieldError('cost_price'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.s12),
                        _buildMarginCalculator(context, isDark),
                      ],
                    ),

                    const SizedBox(height: AppSizes.s16),

                    // Card 4: Manajemen Stok
                    _FormSectionCard(
                      title: ProductStrings.sectionStockManage,
                      subtitle: ProductStrings.sectionStockManageSubtitle,
                      icon: AppIcons.boxes,
                      iconColor: AppColors.amber500,
                      children: [
                        AppSwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(ProductStrings.switchTrackStock, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text(ProductStrings.switchTrackStockSubtitle, style: TextStyle(fontSize: 12)),
                          value: _trackStock,
                          onChanged: (value) => setState(() => _trackStock = value),
                        ),
                        if (_trackStock) ...[
                          const SizedBox(height: AppSizes.s12),
                          if (_isNew) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _stock,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onTapOutside: (_) => unfocus?.call(),
                                    decoration: InputDecoration(
                                      labelText: ProductStrings.fieldInitialStock,
                                      hintText: ProductStrings.hintZero,
                                      prefixIcon: const Icon(AppIcons.box, size: AppSizes.s18),
                                      errorText: _error?.fieldError('stock'),
                                      helperText: ProductStrings.helperInitialStock,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.s12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _minStock,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onTapOutside: (_) => unfocus?.call(),
                                    decoration: InputDecoration(
                                      labelText: ProductStrings.fieldMinimumLimit,
                                      hintText: ProductStrings.hintZero,
                                      prefixIcon: const Icon(AppIcons.alertCircle, size: AppSizes.s18),
                                      errorText: _error?.fieldError('min_stock'),
                                      helperText: ProductStrings.helperMinStock,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_p != null) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s12),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.slate800 : AppColors.slate100).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(AppRadius.r12),
                                border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.s8),
                                    decoration: BoxDecoration(
                                      color: (_p.isOutOfStock
                                              ? status.danger
                                              : _p.isLowStock
                                                  ? status.warning
                                                  : AppColors.emerald500)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      AppIcons.box,
                                      size: AppSizes.s18,
                                      color: _p.isOutOfStock
                                          ? status.danger
                                          : _p.isLowStock
                                              ? status.warning
                                              : AppColors.emerald500,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ProductStrings.labelCurrentStock, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                                        const SizedBox(height: AppSizes.s2),
                                        Text(
                                          ProductStrings.stockQuantity(editableQuantity(_p.stock), _p.unit),
                                          style: AppTypography.quantity(fontSize: 16, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_p.isOutOfStock)
                                    const StatusBadge(label: ProductStrings.statusOutOfStock, tone: BadgeTone.danger)
                                  else if (_p.isLowStock)
                                    const StatusBadge(label: ProductStrings.statusLowStock, tone: BadgeTone.warning)
                                  else
                                    const StatusBadge(label: ProductStrings.statusAvailable, tone: BadgeTone.success),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSizes.s12),
                            TextFormField(
                              controller: _minStock,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onTapOutside: (_) => unfocus?.call(),
                              decoration: InputDecoration(
                                labelText: ProductStrings.fieldMinimumStockEdit,
                                hintText: ProductStrings.hintZero,
                                prefixIcon: const Icon(AppIcons.alertCircle, size: AppSizes.s18),
                                errorText: _error?.fieldError('min_stock'),
                                helperText: ProductStrings.helperMinStockEdit,
                              ),
                            ),
                            const SizedBox(height: AppSizes.s8),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(AppRadius.r10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(AppIcons.info, size: AppSizes.s14, color: theme.colorScheme.primary),
                                  const SizedBox(width: AppSizes.s8),
                                  Expanded(
                                    child: Text(
                                      ProductStrings.infoStockAuditNotice,
                                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),

                    const SizedBox(height: AppSizes.s16),

                    // Card 5: Status Penjualan
                    _FormSectionCard(
                      title: ProductStrings.sectionStatusAvailability,
                      subtitle: ProductStrings.sectionStatusAvailabilitySubtitle,
                      icon: AppIcons.store,
                      iconColor: _isActive ? AppColors.emerald500 : theme.colorScheme.onSurfaceVariant,
                      trailing: StatusBadge(
                        label: _isActive ? ProductStrings.statusActive : ProductStrings.statusInactive,
                        tone: _isActive ? BadgeTone.success : BadgeTone.muted,
                      ),
                      children: [
                        AppSwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(ProductStrings.switchActiveForSale, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            _isActive
                                ? ProductStrings.switchActiveForSaleSubtitleOn
                                : ProductStrings.switchActiveForSaleSubtitleOff,
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _isActive,
                          onChanged: (value) => setState(() => _isActive = value),
                        ),
                      ],
                    ),

                    if (generalError != null) ...[
                      const SizedBox(height: AppSizes.s16),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: status.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.r12),
                          border: Border.all(color: status.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(AppIcons.alertOctagon, size: AppSizes.s18, color: status.danger),
                            const SizedBox(width: AppSizes.s10),
                            Expanded(
                              child: Text(
                                generalError,
                                style: TextStyle(color: status.danger, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s10, AppSpacing.s16, AppSpacing.s10),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                    ),
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox.square(dimension: AppSizes.s20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(AppIcons.check, size: AppSizes.s20),
                    label: Text(
                      _isNew ? ProductStrings.actionSaveNewProduct : ProductStrings.actionSaveChanges,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingProductBanner(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final p = _p;
    if (p == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Row(
        children: [
          ProductThumb(url: p.imageUrl, name: p.name, size: 52),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.s2),
                Text(
                  p.sku.isNotEmpty ? ProductStrings.productSkuLabel(p.sku) : ProductStrings.productIdLabel(p.id),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: _isActive ? ProductStrings.statusActive : ProductStrings.statusInactive,
            tone: _isActive ? BadgeTone.success : BadgeTone.muted,
          ),
        ],
      ),
    );
  }

  Widget _buildNewProductBanner(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.emerald900.withValues(alpha: 0.35), AppColors.slate900]
              : [AppColors.emerald50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: isDark ? AppColors.emerald800 : AppColors.emerald200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s10),
            decoration: BoxDecoration(
              color: AppColors.emerald500.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(AppIcons.sparkles, size: AppSizes.s20, color: AppColors.emerald500),
          ),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  ProductStrings.titleNewProduct,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: AppSizes.s2),
                Text(
                  ProductStrings.newProductBannerBody,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginCalculator(BuildContext context, bool isDark) {
    final sellPrice = parseRupiah(_price.text);
    final costPrice = parseRupiah(_cost.text);
    final theme = Theme.of(context);
    final status = StatusColors.of(context);

    if (sellPrice == 0 && costPrice == 0) {
      return const SizedBox.shrink();
    }

    if (costPrice == 0) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.slate800 : AppColors.slate100).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: Row(
          children: [
            Icon(AppIcons.info, size: AppSizes.s16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSizes.s8),
            Expanded(
              child: Text(
                ProductStrings.marginCostHint,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    final profit = sellPrice - costPrice;
    final isProfit = profit >= 0;
    final marginPercent = sellPrice > 0 ? (profit / sellPrice * 100) : 0.0;
    final markupPercent = costPrice > 0 ? (profit / costPrice * 100) : 0.0;

    final accentColor = isProfit ? AppColors.emerald500 : status.danger;
    final bgColor = isProfit
        ? (isDark ? AppColors.emerald900.withValues(alpha: 0.3) : AppColors.emerald50)
        : (isDark ? AppColors.red900.withValues(alpha: 0.3) : AppColors.red50);
    final borderColor = isProfit
        ? (isDark ? AppColors.emerald800 : AppColors.emerald200)
        : (isDark ? AppColors.red800 : AppColors.rose100);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isProfit ? AppIcons.trendingUp : AppIcons.alertTriangle,
                    size: AppSizes.s16,
                    color: accentColor,
                  ),
                  const SizedBox(width: AppSizes.s6),
                  Text(
                    isProfit ? ProductStrings.marginProfitTitle : ProductStrings.marginLossTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.r6),
                ),
                child: Text(
                  ProductStrings.marginPercentLabel(marginPercent.toStringAsFixed(1)),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProductStrings.profitPerUnitLabel(_unit.text.trim().isEmpty ? ProductStrings.unitFallback : _unit.text.trim()),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    ProductStrings.signedAmount(profit >= 0 ? '+' : '-', rupiah(profit.abs())),
                    style: AppTypography.money(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              if (isProfit && costPrice > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ProductStrings.marginMarkupTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Text(
                      ProductStrings.markupPercentLabel(markupPercent.toStringAsFixed(1)),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    required this.children,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = iconColor ?? theme.colorScheme.primary;

    return Material(
      color: isDark ? AppColors.slate800 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
        side: BorderSide(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                ),
                child: Icon(icon, size: AppSizes.s18, color: color),
              ),
              const SizedBox(width: AppSizes.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSizes.s2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSizes.s16),
          ...children,
        ],
      ),
    ),
  );
}
}
