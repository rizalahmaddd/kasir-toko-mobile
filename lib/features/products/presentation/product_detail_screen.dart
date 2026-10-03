import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import '../products_providers.dart';
import 'movement_tile.dart';
import 'product_widgets.dart';
import 'stock_adjust_sheet.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));
    final user = ref.watch(currentUserProvider);
    final canManage = user?.canManageMasterData ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.value?.name ?? ProductStrings.appTitleProducts, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (canManage && product.value != null) ...[
            IconButton(
              tooltip: ProductStrings.actionEdit,
              icon: const Icon(AppIcons.pencil, size: AppSizes.s20),
              onPressed: () => context.push(AppRoutes.productEdit(productId)),
            ),
            IconButton(
              tooltip: ProductStrings.actionDelete,
              icon: const Icon(AppIcons.trash2, size: AppSizes.s20),
              onPressed: product.value == null ? null : () => _delete(context, ref, product.value!),
            ),
          ],
        ],
      ),
      body: AsyncView(
        value: product,
        onRetry: () => ref.invalidate(productDetailProvider(productId)),
        loading: const ProductDetailSkeleton(),
        data: (product) => RefreshIndicator(
          onRefresh: () => ref.refresh(productDetailProvider(productId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(product: product, canManage: canManage),
                    const SizedBox(height: AppSizes.s16),
                    _PricingAndSpecsCard(product: product),
                    if (product.trackStock) ...[
                      const SectionTitle(ProductStrings.sectionStock),
                      _StockCard(product: product, canAdjust: user?.canAdjustStock ?? false),
                      if (user?.canViewStock ?? false) _RecentMovements(product: product),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ProductRecord product) async {
    final ok = await confirmAction(
      context,
      title: ProductStrings.deleteProductConfirmTitle,
      message: ProductStrings.productDeleteConfirmMessage(product.name),
      confirmLabel: ProductStrings.deleteProductConfirmAction,
      danger: true,
    );
    if (!ok || !context.mounted) {
      return;
    }

    try {
      await ref.read(productsRepositoryProvider).deleteProduct(product.id);
      ref.read(productsProvider.notifier).remove((item) => item.id == product.id);
      ref.read(dataChangesProvider).after({DataChange.products});
      if (context.mounted) {
        context.pop();
        showMessage(context, ProductStrings.productDeletedMessage(product.name));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }
}

class _Header extends ConsumerStatefulWidget {
  const _Header({required this.product, required this.canManage});

  final ProductRecord product;
  final bool canManage;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final hasImage = widget.product.imageUrl != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHeader(title: ProductStrings.photoSheetTitle),
            ListTile(leading: const Icon(AppIcons.camera), title: const Text(ProductStrings.actionTakePhoto), onTap: () => Navigator.pop(context, 'camera')),
            ListTile(leading: const Icon(AppIcons.image), title: const Text(ProductStrings.actionPickFromGallery), onTap: () => Navigator.pop(context, 'gallery')),
            if (hasImage)
              ListTile(
                leading: Icon(AppIcons.trash2, color: StatusColors.of(context).danger),
                title: Text(ProductStrings.actionDeletePhoto, style: TextStyle(color: StatusColors.of(context).danger)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            const SizedBox(height: AppSizes.s12),
          ],
        ),
      ),
    );
    if (choice == null) {
      return;
    }

    final repository = ref.read(productsRepositoryProvider);
    try {
      if (choice == 'delete') {
        setState(() => _uploading = true);
        await repository.deleteImage(widget.product.id);
      } else {
        final file = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        if (file == null) {
          return;
        }
        setState(() => _uploading = true);
        await repository.uploadImage(widget.product.id, file.path);
      }
      ref.read(dataChangesProvider).after({DataChange.products});
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);

    return Row(
      children: [
        GestureDetector(
          onTap: widget.canManage && !_uploading ? _changePhoto : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ProductThumb(url: product.imageUrl, name: product.name, size: 88),
              if (_uploading) const CircularProgressIndicator(),
              if (widget.canManage && !_uploading)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(AppIcons.camera, size: AppSizes.s14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSizes.s2),
              Text(product.sku, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSizes.s8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(label: product.isActive ? ProductStrings.statusActive : ProductStrings.statusInactive, tone: product.isActive ? BadgeTone.success : BadgeTone.muted),
                  if (product.isOutOfStock)
                    const StatusBadge(label: ProductStrings.statusOutOfStock, tone: BadgeTone.danger)
                  else if (product.isLowStock)
                    const StatusBadge(label: ProductStrings.statusLowStockLong, tone: BadgeTone.warning),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PricingAndSpecsCard extends StatelessWidget {
  const _PricingAndSpecsCard({required this.product});

  final ProductRecord product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final marginPercent = product.price > 0 ? (product.margin / product.price * 100) : 0.0;
    final isPositiveMargin = product.margin >= 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r16),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ProductStrings.labelSellingPrice, style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    rupiah(product.price),
                    style: AppTypography.money(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emerald600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s5),
                decoration: BoxDecoration(
                  color: isPositiveMargin
                      ? AppColors.emerald500.withValues(alpha: 0.12)
                      : colors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositiveMargin ? AppIcons.trendingUp : AppIcons.trendingDown,
                      size: AppSizes.s14,
                      color: isPositiveMargin ? AppColors.emerald600 : colors.danger,
                    ),
                    const SizedBox(width: AppSizes.s4),
                    Text(
                      ProductStrings.priceMarginLabel(isPositiveMargin, rupiah(product.margin), marginPercent.toStringAsFixed(1)),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPositiveMargin ? AppColors.emerald600 : colors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.slate50,
              borderRadius: BorderRadius.circular(AppRadius.r10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ProductStrings.labelCostPrice, style: TextStyle(fontSize: 13, color: muted)),
                Text(
                  rupiah(product.costPrice),
                  style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: Divider(height: 1),
          ),
          InfoRow(ProductStrings.labelUnit, product.unit),
          InfoRow(ProductStrings.labelCategory, product.category?.name ?? '-'),
          InfoRow(ProductStrings.labelBarcode, product.barcode ?? '-'),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.product, required this.canAdjust});

  final ProductRecord product;
  final bool canAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r16),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ProductStrings.labelCurrentStock, style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSizes.s2),
                  Text(
                    ProductStrings.stockQuantity(quantity(product.stock), product.unit),
                    style: AppTypography.quantity(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: product.isOutOfStock
                          ? colors.danger
                          : (product.isLowStock ? colors.warning : null),
                    ),
                  ),
                ],
              ),
              if (product.isOutOfStock)
                const StatusBadge(label: ProductStrings.statusOutOfStock, tone: BadgeTone.danger)
              else if (product.isLowStock)
                const StatusBadge(label: ProductStrings.statusLowStock, tone: BadgeTone.warning)
              else
                const StatusBadge(label: ProductStrings.statusAvailable, tone: BadgeTone.success),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          InfoRow(ProductStrings.labelMinimumLimit, ProductStrings.stockQuantity(quantity(product.minStock), product.unit)),
          InfoRow(ProductStrings.labelStockValueCost, rupiah((product.stock > 0 ? product.stock : 0) * product.costPrice)),
          if (canAdjust) ...[
            const SizedBox(height: AppSizes.s14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                    ),
                    onPressed: () => StockAdjustSheet.show(context, product, MovementTypes.stockIn),
                    icon: const Icon(AppIcons.arrowDownToLine, size: AppSizes.s16),
                    label: const Text(ProductStrings.actionStockInShort, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                    ),
                    onPressed: () => StockAdjustSheet.show(context, product, MovementTypes.stockOut),
                    icon: const Icon(AppIcons.arrowUpFromLine, size: AppSizes.s16),
                    label: const Text(ProductStrings.actionStockOutShort, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                    ),
                    onPressed: () => StockAdjustSheet.show(context, product, MovementTypes.opname),
                    icon: const Icon(AppIcons.clipboardCheck, size: AppSizes.s16),
                    label: const Text(ProductStrings.actionOpnameShort, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentMovements extends ConsumerWidget {
  const _RecentMovements({required this.product});

  final ProductRecord product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(movementsProvider((productId: product.id, type: null, search: '')));
    final items = movements.value?.items.take(5).toList() ?? const <StockMovement>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          ProductStrings.sectionStockCard,
          trailing: TextButton(onPressed: () => context.push(AppRoutes.stockMovementsFor(product.id, product.name)), child: const Text(ProductStrings.actionViewAll)),
        ),
        if (movements.isLoading && items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: DefaultListSkeleton(itemCount: 3, padding: EdgeInsets.zero, shrinkWrap: true),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s8),
            child: Text(ProductStrings.emptyInlineMovements, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          Column(children: [for (final movement in items) MovementTile(movement: movement, margin: const EdgeInsets.only(bottom: AppSpacing.s6))]),
      ],
    );
  }
}
