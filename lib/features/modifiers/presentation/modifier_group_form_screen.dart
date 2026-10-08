import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/data/pos_models.dart';
import '../../pos/data/pos_repository.dart';
import '../data/modifier_groups_repository.dart';
import '../modifiers_providers.dart';

class _OptionDraft {
  _OptionDraft([ModifierOptionRecord? option])
      : id = option?.id,
        productId = option?.productId,
        ingredientQuantity = option?.ingredientQuantity,
        isActive = option?.isActive ?? true,
        name = TextEditingController(text: option?.name ?? ''),
        price = TextEditingController(text: option == null || option.price == 0 ? '' : thousands(option.price));

  final int? id;
  final int? productId;
  final String? ingredientQuantity;
  bool isActive;
  final TextEditingController name;
  final TextEditingController price;

  void dispose() {
    name.dispose();
    price.dispose();
  }

  Map<String, dynamic> toJson() => ModifierOptionRecord(
        id: id,
        name: name.text.trim(),
        price: parseRupiah(price.text),
        productId: productId,
        ingredientQuantity: ingredientQuantity,
        isActive: isActive,
      ).toJson();
}

/// Tambah / ubah grup pilihan tambahan. [groupId] null berarti grup baru.
class ModifierGroupFormScreen extends ConsumerWidget {
  const ModifierGroupFormScreen({super.key, this.groupId});

  final int? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groupId == null) {
      return const _Form();
    }

    return AsyncView<ModifierGroupRecord>(
      value: ref.watch(modifierGroupProvider(groupId!)),
      onRetry: () => ref.invalidate(modifierGroupProvider(groupId!)),
      data: (group) => _Form(group: group),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.group});

  final ModifierGroupRecord? group;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final _min = TextEditingController(text: '${widget.group?.minSelect ?? 0}');
  late final _max = TextEditingController(text: widget.group == null ? '1' : (widget.group!.maxSelect?.toString() ?? ''));
  late bool _active = widget.group?.isActive ?? true;
  late final List<_OptionDraft> _options = widget.group == null ? [_OptionDraft()] : widget.group!.options.map(_OptionDraft.new).toList();
  late final List<({int id, String name})> _products = [...?widget.group?.products];
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final controller in [_name, _min, _max]) {
      controller.dispose();
    }
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  Future<void> _addProduct() async {
    final product = await showModalBottomSheet<Product>(context: context, isScrollControlled: true, builder: (_) => const _ProductPickerSheet());
    if (product != null && !_products.any((p) => p.id == product.id)) {
      setState(() => _products.add((id: product.id, name: product.name)));
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(modifierGroupsRepositoryProvider).save({
        'name': _name.text.trim(),
        'min_select': int.tryParse(_min.text.trim()) ?? 0,
        'max_select': _max.text.trim().isEmpty ? null : int.tryParse(_max.text.trim()),
        'is_active': _active,
        'options': [for (final option in _options) if (option.name.text.trim().isNotEmpty) option.toJson()],
        'product_ids': [for (final product in _products) product.id],
      }, id: widget.group?.id);
      ref.invalidate(modifierGroupsProvider);
      if (widget.group != null) {
        ref.invalidate(modifierGroupProvider(widget.group!.id));
      }
      if (mounted) {
        showMessage(context, ModifierStrings.saved);
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ModifierStrings.deleteTitle),
        content: const Text(ModifierStrings.deleteHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(OrderStrings.back)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(ModifierStrings.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(modifierGroupsRepositoryProvider).delete(widget.group!.id);
      ref.invalidate(modifierGroupsProvider);
      if (mounted) {
        showMessage(context, ModifierStrings.deleted);
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? ModifierStrings.newGroup : widget.group!.name),
        actions: [if (widget.group != null) IconButton(tooltip: ModifierStrings.delete, onPressed: _delete, icon: const Icon(AppIcons.trash2))],
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: ModifierStrings.name, hintText: ModifierStrings.nameHint, errorText: error?.fieldError('name'))),
            const SizedBox(height: AppSizes.s12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: ModifierStrings.minSelect, errorText: error?.fieldError('min_select')),
                  ),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: ModifierStrings.maxSelect, hintText: ModifierStrings.unlimited, errorText: error?.fieldError('max_select')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s6),
            Text(ModifierStrings.ruleHint, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            AppSwitchListTile(contentPadding: EdgeInsets.zero, title: const Text(ModifierStrings.active), value: _active, onChanged: (value) => setState(() => _active = value)),
            SectionTitle(
              ModifierStrings.options,
              trailing: TextButton.icon(
                onPressed: _options.length >= 30 ? null : () => setState(() => _options.add(_OptionDraft())),
                icon: const Icon(AppIcons.plus, size: AppSizes.s16),
                label: const Text(ModifierStrings.addOption),
              ),
            ),
            if (error?.fieldError('options') != null) Text(error!.fieldError('options')!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            for (final (index, option) in _options.indexed)
              Padding(
                key: ObjectKey(option),
                padding: const EdgeInsets.only(top: AppSpacing.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(controller: option.name, decoration: InputDecoration(labelText: ModifierStrings.optionName, errorText: error?.fieldError('options.$index.name'))),
                    ),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      flex: 2,
                      child: TextField(controller: option.price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: ModifierStrings.optionPrice, prefixText: '+Rp ')),
                    ),
                    Checkbox(value: option.isActive, onChanged: (value) => setState(() => option.isActive = value ?? true)),
                    IconButton(onPressed: () => setState(() => _options.removeAt(index).dispose()), icon: const Icon(AppIcons.trash2, size: AppSizes.s18)),
                  ],
                ),
              ),
            SectionTitle(
              ModifierStrings.products,
              trailing: TextButton.icon(onPressed: _addProduct, icon: const Icon(AppIcons.plus, size: AppSizes.s16), label: const Text(ModifierStrings.addProduct)),
            ),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                for (final product in _products) InputChip(label: Text(product.name), onDeleted: () => setState(() => _products.removeWhere((p) => p.id == product.id))),
              ],
            ),
            if (error != null && error.fieldErrors.isEmpty) ...[
              const SizedBox(height: AppSizes.s12),
              Text(error.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSizes.s20),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? OrderStrings.saving : ModifierStrings.save)),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  Timer? _debounce;
  List<Product> _results = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String term) async {
    try {
      final page = await ref.read(posRepositoryProvider).products(search: term);
      if (mounted) {
        setState(() => _results = page.items);
      }
    } on ApiException {
      // daftar lama tetap ditampilkan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHeader(title: ModifierStrings.addProduct),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(AppIcons.search)),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () => _search(value.trim()));
                },
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) => ListTile(onTap: () => Navigator.pop(context, _results[index]), title: Text(_results[index].name)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
