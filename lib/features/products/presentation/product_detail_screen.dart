import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import '../products_providers.dart';
import 'movement_tile.dart';
import 'product_widgets.dart';
import 'stock_adjust_sheet.dart';

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
        title: Text(product.value?.name ?? 'Produk', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (canManage && product.value != null) ...[
            IconButton(
              tooltip: 'Ubah',
              icon: const Icon(LucideIcons.pencil, size: 20),
              onPressed: () => context.push('/product/$productId/edit'),
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(LucideIcons.trash2, size: 20),
              onPressed: () => _delete(context, ref, product.value!),
            ),
          ],
        ],
      ),
      body: AsyncView(
        value: product,
        onRetry: () => ref.invalidate(productDetailProvider(productId)),
        data: (product) => RefreshIndicator(
          onRefresh: () => ref.refresh(productDetailProvider(productId).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(product: product, canManage: canManage),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            InfoRow('Harga jual', rupiah(product.price), bold: true),
                            InfoRow('Harga modal', rupiah(product.costPrice)),
                            InfoRow(
                              'Margin',
                              product.price == 0 ? '-' : '${rupiah(product.margin)} (${(product.margin / product.price * 100).toStringAsFixed(1)}%)',
                              valueColor: product.margin < 0 ? StatusColors.of(context).danger : StatusColors.of(context).success,
                            ),
                            const Divider(height: 24),
                            InfoRow('Satuan', product.unit),
                            InfoRow('Kategori', product.category?.name ?? '-'),
                            InfoRow('Barcode', product.barcode ?? '-'),
                          ],
                        ),
                      ),
                    ),
                    if (product.trackStock) ...[
                      const SectionTitle('Stok'),
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
      title: 'Hapus produk?',
      message: '${product.name} tidak akan muncul lagi di kasir. Riwayat transaksi tetap tersimpan.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok || !context.mounted) {
      return;
    }

    try {
      await ref.read(productsRepositoryProvider).deleteProduct(product.id);
      ref.read(productsProvider.notifier).remove((item) => item.id == product.id);
      if (context.mounted) {
        context.pop();
        showMessage(context, '${product.name} dihapus.');
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
            ListTile(leading: const Icon(LucideIcons.camera), title: const Text('Ambil foto'), onTap: () => Navigator.pop(context, 'camera')),
            ListTile(leading: const Icon(LucideIcons.image), title: const Text('Pilih dari galeri'), onTap: () => Navigator.pop(context, 'gallery')),
            if (hasImage)
              ListTile(
                leading: Icon(LucideIcons.trash2, color: StatusColors.of(context).danger),
                title: Text('Hapus foto', style: TextStyle(color: StatusColors.of(context).danger)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
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
      ref
        ..invalidate(productDetailProvider(widget.product.id))
        ..invalidate(productsProvider);
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
              ProductThumb(url: product.imageUrl, size: 88),
              if (_uploading) const CircularProgressIndicator(),
              if (widget.canManage && !_uploading)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(product.sku, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(label: product.isActive ? 'Aktif' : 'Nonaktif', tone: product.isActive ? BadgeTone.success : BadgeTone.muted),
                  if (product.isOutOfStock)
                    const StatusBadge(label: 'Habis', tone: BadgeTone.danger)
                  else if (product.isLowStock)
                    const StatusBadge(label: 'Stok menipis', tone: BadgeTone.warning),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.product, required this.canAdjust});

  final ProductRecord product;
  final bool canAdjust;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoRow(
              'Stok saat ini',
              '${quantity(product.stock)} ${product.unit}',
              bold: true,
              valueColor: product.isOutOfStock ? colors.danger : (product.isLowStock ? colors.warning : null),
            ),
            InfoRow('Batas minimum', '${quantity(product.minStock)} ${product.unit}'),
            InfoRow('Nilai stok (modal)', rupiah((product.stock > 0 ? product.stock : 0) * product.costPrice)),
            if (canAdjust) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => StockAdjustSheet.show(context, product, 'stock_in'),
                    icon: const Icon(LucideIcons.arrowDownToLine, size: 18),
                    label: const Text('Stok Masuk'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => StockAdjustSheet.show(context, product, 'stock_out'),
                    icon: const Icon(LucideIcons.arrowUpFromLine, size: 18),
                    label: const Text('Stok Keluar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => StockAdjustSheet.show(context, product, 'opname'),
                    icon: const Icon(LucideIcons.clipboardCheck, size: 18),
                    label: const Text('Opname'),
                  ),
                ],
              ),
            ],
          ],
        ),
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
          'Kartu stok',
          trailing: TextButton(onPressed: () => context.push('/stock/movements?product=${product.id}&name=${Uri.encodeComponent(product.name)}'), child: const Text('Lihat semua')),
        ),
        if (movements.isLoading && items.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Belum ada mutasi stok.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          Card(child: Column(children: [for (final movement in items) MovementTile(movement: movement)])),
      ],
    );
  }
}
