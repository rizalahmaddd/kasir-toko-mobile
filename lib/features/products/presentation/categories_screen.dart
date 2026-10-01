import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../pos/pos_providers.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import '../products_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(currentUserProvider)?.canManageMasterData ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => FormSheet.show<void>(context, const _CategorySheet()),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Kategori'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(hint: 'Cari kategori', onChanged: ref.read(categoriesSearchProvider.notifier).set),
          ),
          Expanded(
            child: PagedListView(
              value: ref.watch(categoriesProvider),
              onLoadMore: () => ref.read(categoriesProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(categoriesProvider.future),
              padding: const EdgeInsets.only(bottom: 96),
              empty: const EmptyState(icon: LucideIcons.tags, title: 'Belum ada kategori'),
              itemBuilder: (context, category) => ListTile(
                onTap: canManage ? () => FormSheet.show<void>(context, _CategorySheet(category: category)) : null,
                title: Row(
                  children: [
                    Flexible(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (!category.isActive) ...[const SizedBox(width: 6), const StatusBadge(label: 'Nonaktif')],
                  ],
                ),
                subtitle: Text('${category.productsCount ?? 0} produk · urutan ${category.sortOrder}'),
                trailing: canManage ? const Icon(LucideIcons.chevronRight, size: 18) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.category});

  final CategoryRecord? category;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.category?.name);
  late final _order = TextEditingController(text: '${widget.category?.sortOrder ?? 0}');
  late bool _active = widget.category?.isActive ?? true;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  void _refreshLists() => ref
    ..invalidate(categoriesProvider)
    ..invalidate(allCategoriesProvider)
    ..invalidate(posCategoriesProvider);

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(productsRepositoryProvider).saveCategory(
            id: widget.category?.id,
            name: _name.text.trim(),
            sortOrder: int.tryParse(_order.text) ?? 0,
            isActive: _active,
          );
      _refreshLists();
      if (mounted) {
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final category = widget.category!;
    final ok = await confirmAction(
      context,
      title: 'Hapus kategori?',
      message: 'Kategori ${category.name} akan dihapus.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok) {
      return;
    }

    try {
      await ref.read(productsRepositoryProvider).deleteCategory(category.id);
      _refreshLists();
      if (mounted) {
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return FormSheet(
      title: widget.category == null ? 'Kategori baru' : 'Ubah kategori',
      children: [
        TextField(
          controller: _name,
          autofocus: widget.category == null,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Nama kategori', errorText: _error?.fieldError('name')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _order,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(labelText: 'Urutan tampil', helperText: 'Angka kecil tampil lebih dulu di kasir.', errorText: _error?.fieldError('sort_order')),
        ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktif'), value: _active, onChanged: (value) => setState(() => _active = value)),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Simpan')),
        if (widget.category != null)
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: StatusColors.of(context).danger),
            child: const Text('Hapus kategori'),
          ),
      ],
    );
  }
}
