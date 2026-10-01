import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/pos_providers.dart';
import '../../pos/presentation/camera_scanner_screen.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import '../products_providers.dart';

const _units = ['pcs', 'btl', 'bks', 'kg', 'gr', 'ltr', 'dus', 'pak', 'sachet', 'kaleng', 'karung', 'lusin'];

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
      error: (error, _) => Scaffold(appBar: AppBar(), body: ErrorState(error: error, onRetry: () => ref.invalidate(productDetailProvider(productId!)))),
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
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
  void dispose() {
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
      price: parseRupiah(_price.text),
      trackStock: _trackStock,
      stock: _isNew && _trackStock ? parseQuantity(_stock.text) : null,
      minStock: _trackStock ? parseQuantity(_minStock.text) : null,
      isActive: _isActive,
    );

    try {
      final saved = await ref.read(productsRepositoryProvider).saveProduct(input, id: _p?.id);
      ref
        ..invalidate(productsProvider)
        ..invalidate(stockProvider)
        ..invalidate(catalogProvider);
      if (!_isNew) {
        ref.invalidate(productDetailProvider(saved.id));
      }
      if (mounted) {
        showMessage(context, _isNew ? '${saved.name} ditambahkan.' : 'Perubahan disimpan.');
        if (_isNew) {
          context.pushReplacement('/product/${saved.id}');
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
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;
    final unfocus = FocusManager.instance.primaryFocus?.unfocus;

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Produk baru' : 'Ubah produk')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: 'Nama produk', errorText: _error?.fieldError('name')),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Nama produk wajib diisi.' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sku,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(labelText: 'SKU', hintText: 'Kosongkan = otomatis', errorText: _error?.fieldError('sku')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _barcode,
                          decoration: InputDecoration(
                            labelText: 'Barcode',
                            errorText: _error?.fieldError('barcode'),
                            suffixIcon: IconButton(
                              tooltip: 'Scan barcode',
                              icon: const Icon(LucideIcons.scanBarcode, size: 18),
                              onPressed: () async {
                                final code = await CameraScannerScreen.open(context);
                                if (code != null) {
                                  _barcode.text = code;
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                    decoration: InputDecoration(labelText: 'Kategori', errorText: _error?.fieldError('category_id')),
                    items: [
                      const DropdownMenuItem(child: Text('Tanpa kategori')),
                      for (final category in categories) DropdownMenuItem(value: category.id, child: Text(category.name)),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _unit,
                    decoration: InputDecoration(labelText: 'Satuan', errorText: _error?.fieldError('unit')),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Satuan wajib diisi.' : null,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final unit in _units)
                        ChoiceChip(
                          label: Text(unit),
                          selected: _unit.text == unit,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _unit.text = unit),
                        ),
                    ],
                  ),
                  const SectionTitle('Harga'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: MoneyField(controller: _price, label: 'Harga jual', errorText: _error?.fieldError('price'))),
                      const SizedBox(width: 12),
                      Expanded(child: MoneyField(controller: _cost, label: 'Harga modal', errorText: _error?.fieldError('cost_price'))),
                    ],
                  ),
                  const SectionTitle('Stok'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lacak stok'),
                    subtitle: const Text('Matikan untuk jasa atau barang yang tidak dihitung stoknya.'),
                    value: _trackStock,
                    onChanged: (value) => setState(() => _trackStock = value),
                  ),
                  if (_trackStock)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isNew) ...[
                          Expanded(
                            child: TextFormField(
                              controller: _stock,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onTapOutside: (_) => unfocus?.call(),
                              decoration: InputDecoration(labelText: 'Stok awal', errorText: _error?.fieldError('stock')),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: TextFormField(
                            controller: _minStock,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onTapOutside: (_) => unfocus?.call(),
                            decoration: InputDecoration(labelText: 'Batas minimum', errorText: _error?.fieldError('min_stock')),
                          ),
                        ),
                      ],
                    ),
                  if (!_isNew && _trackStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Ubah jumlah stok lewat Stok Masuk/Keluar/Opname di halaman produk.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif dijual'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  if (generalError != null) ...[
                    const SizedBox(height: 8),
                    Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
