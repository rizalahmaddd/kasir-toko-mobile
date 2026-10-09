import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/product_meta.dart';
import '../../pos/cart_math.dart';
import '../data/product_models.dart';

class UnitDraft {
  UnitDraft({this.id, String name = '', String factor = '', String price = '', String barcode = '', this.isDefault = false})
      : name = TextEditingController(text: name),
        factor = TextEditingController(text: factor),
        price = TextEditingController(text: price),
        barcode = TextEditingController(text: barcode);

  final int? id;
  final TextEditingController name;
  final TextEditingController factor;
  final TextEditingController price;
  final TextEditingController barcode;
  bool isDefault;

  void dispose() {
    for (final controller in [name, factor, price, barcode]) {
      controller.dispose();
    }
  }
}

class VariantOptionDraft {
  VariantOptionDraft({String name = '', String values = ''})
      : name = TextEditingController(text: name),
        values = TextEditingController(text: values);

  final TextEditingController name;
  final TextEditingController values;

  void dispose() {
    name.dispose();
    values.dispose();
  }
}

class TierDraft {
  TierDraft({String min = '', String price = ''}) : min = TextEditingController(text: min), price = TextEditingController(text: price);

  final TextEditingController min;
  final TextEditingController price;

  void dispose() {
    min.dispose();
    price.dispose();
  }
}

/// Isian kapabilitas usaha di form produk. Hanya isian dari kapabilitas yang menyala yang ikut dikirim.
class ProductBusinessDraft {
  ProductBusinessDraft(ProductRecord? product)
    : attributes = {for (final entry in (product?.customAttributes ?? const {}).entries) entry.key: '${entry.value}'},
      drugClass = product?.drugClass,
      requiresPrescription = product?.requiresPrescription ?? false,
      trackBatch = product?.trackBatch ?? false,
      units = [
        for (final unit in product?.units ?? const <ProductUnitRecord>[])
          UnitDraft(
            id: unit.id,
            name: unit.name,
            factor: editableQuantity(unit.factor),
            price: unit.fixedPrice == null ? '' : thousands(unit.fixedPrice!),
            barcode: unit.barcode ?? '',
            isDefault: unit.isDefault,
          ),
      ],
tiers = [for (final tier in product?.priceTiers ?? const <PriceTier>[]) TierDraft(min: editableQuantity(tier.min), price: thousands(tier.price))],
        trackSerial = product?.trackSerial ?? false,
        warrantyDays = TextEditingController(text: product?.warrantyDays?.toString() ?? ''),
        isVariant = product?.parentId != null,
        variantOptions = [for (final option in product?.variantOptions ?? const <({String name, List<String> values})>[]) VariantOptionDraft(name: option.name, values: option.values.join(', '))];

  final Map<String, String> attributes;
  String? drugClass;
  bool requiresPrescription;
  bool trackBatch;
  final List<UnitDraft> units;
  final List<TierDraft> tiers;
  bool trackSerial;
  final TextEditingController warrantyDays;

  /// Produk ini sendiri adalah SKU anak, jadi tidak bisa punya varian lagi.
  final bool isVariant;
  final List<VariantOptionDraft> variantOptions;
  final batchNumber = TextEditingController();
  DateTime? expiresAt;

  void dispose() {
    batchNumber.dispose();
    for (final unit in units) {
      unit.dispose();
    }
    for (final tier in tiers) {
      tier.dispose();
    }
    warrantyDays.dispose();
    for (final option in variantOptions) {
      option.dispose();
    }
  }

  Map<String, dynamic> toJson(WidgetRef ref, {required bool isNew, required bool trackStock}) {
    final user = ref.read(currentUserProvider);

    return {
      if (user?.usesProductAttributes ?? false) 'custom_attributes': {for (final entry in attributes.entries) entry.key: entry.value.trim().isEmpty ? null : entry.value.trim()},
      if (user?.usesPrescriptions ?? false) ...{'drug_class': drugClass, 'requires_prescription': requiresPrescription},
      if (user?.usesBatches ?? false) 'track_batch': trackBatch && trackStock,
      if ((user?.usesBatches ?? false) && isNew && trackBatch && batchNumber.text.trim().isNotEmpty) 'batch_number': batchNumber.text.trim(),
      if ((user?.usesBatches ?? false) && isNew && trackBatch && expiresAt != null) 'expires_at': expiresAt!.toIso8601String().substring(0, 10),
      if (user?.usesSerials ?? false) ...{
        'track_serial': trackSerial && trackStock,
        'warranty_days': int.tryParse(warrantyDays.text.trim()),
      },
      if ((user?.usesVariants ?? false) && !isVariant)
        'variant_options': [
          for (final option in variantOptions)
            if (option.name.text.trim().isNotEmpty) {'name': option.name.text.trim(), 'values': option.values.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList()},
        ],
      if (user?.usesTieredPrice ?? false)
        'price_tiers': [
          for (final tier in tiers)
            if (tier.min.text.trim().isNotEmpty)
              {'min_quantity': double.tryParse(tier.min.text.trim().replaceAll(',', '.')) ?? 0, 'price': parseRupiah(tier.price.text)},
        ],
      if (user?.usesMultiUnit ?? false)
        'units': [
          for (final unit in units)
            if (unit.name.text.trim().isNotEmpty)
              {
                'id': ?unit.id,
                'name': unit.name.text.trim(),
                'factor': double.tryParse(unit.factor.text.trim().replaceAll(',', '.')) ?? 0,
                'price': unit.price.text.trim().isEmpty ? null : parseRupiah(unit.price.text),
                'barcode': unit.barcode.text.trim().isEmpty ? null : unit.barcode.text.trim(),
                'is_default_sale': unit.isDefault,
              },
        ],
    };
  }
}

class ProductBusinessSection extends ConsumerStatefulWidget {
  const ProductBusinessSection({super.key, required this.draft, required this.baseUnit, required this.trackStock, required this.isNew, this.fieldError});

  final ProductBusinessDraft draft;
  final String baseUnit;
  final bool trackStock;
  final bool isNew;
  final String? Function(String field)? fieldError;

  @override
  ConsumerState<ProductBusinessSection> createState() => _ProductBusinessSectionState();
}

class _ProductBusinessSectionState extends ConsumerState<ProductBusinessSection> {
  ProductBusinessDraft get _draft => widget.draft;

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.expiresAt ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _draft.expiresAt = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final meta = ref.watch(productMetaProvider).value ?? const ProductMeta();
    final showAttributes = (user?.usesProductAttributes ?? false) && meta.attributes.isNotEmpty;
    final showPharmacy = user?.usesPrescriptions ?? false;
    final showBatch = (user?.usesBatches ?? false) && widget.trackStock;
    final showUnits = user?.usesMultiUnit ?? false;
    final showTiers = user?.usesTieredPrice ?? false;
    final showSerial = user?.usesSerials ?? false;
    final showVariants = (user?.usesVariants ?? false) && !_draft.isVariant;

    if (!showAttributes && !showPharmacy && !showBatch && !showUnits && !showTiers && !showSerial && !showVariants) {
      return const SizedBox.shrink();
    }

    final error = widget.fieldError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(BusinessStrings.sectionTitle),
        if (showPharmacy) ...[
          DropdownButtonFormField<String?>(
            initialValue: _draft.drugClass,
            decoration: InputDecoration(labelText: BusinessStrings.drugClass, errorText: error?.call('drug_class')),
            items: [
              const DropdownMenuItem(value: null, child: Text(BusinessStrings.drugClassNone)),
              for (final entry in meta.drugClasses.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() {
              _draft.drugClass = value;
              _draft.requiresPrescription = const {'keras', 'psikotropika', 'narkotika'}.contains(value);
            }),
          ),
          AppSwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(BusinessStrings.requiresPrescription),
            subtitle: const Text(BusinessStrings.requiresPrescriptionHint, style: TextStyle(fontSize: 12)),
            value: _draft.requiresPrescription,
            onChanged: (value) => setState(() => _draft.requiresPrescription = value),
          ),
        ],
        if (showAttributes)
          for (final field in meta.attributes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: _attributeField(field, error?.call('custom_attributes.${field.key}')),
            ),
        if (showBatch) ...[
          AppSwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(BusinessStrings.trackBatch),
            subtitle: const Text(BusinessStrings.trackBatchHint, style: TextStyle(fontSize: 12)),
            value: _draft.trackBatch,
            onChanged: (value) => setState(() => _draft.trackBatch = value),
          ),
          if (_draft.trackBatch && widget.isNew)
            Row(
              children: [
                Expanded(child: TextField(controller: _draft.batchNumber, decoration: const InputDecoration(labelText: BusinessStrings.batchNumber))),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickExpiry,
                    icon: const Icon(AppIcons.calendar, size: AppSizes.s16),
                    label: Text(_draft.expiresAt == null ? BusinessStrings.expiresAtPick : dateOnly(_draft.expiresAt!)),
                  ),
                ),
              ],
            ),
        ],
        if (showSerial) ...[
          AppSwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(BusinessStrings.trackSerial),
            subtitle: const Text(BusinessStrings.trackSerialHint),
            value: _draft.trackSerial && widget.trackStock,
            onChanged: widget.trackStock ? (value) => setState(() => _draft.trackSerial = value) : null,
          ),
          TextField(
            controller: _draft.warrantyDays,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: BusinessStrings.warrantyDays, errorText: error?.call('warranty_days')),
          ),
          const SizedBox(height: AppSizes.s12),
        ],
        if (showVariants) ...[
          SectionTitle(
            BusinessStrings.variantsTitle,
            trailing: TextButton.icon(
              onPressed: _draft.variantOptions.length >= 3 ? null : () => setState(() => _draft.variantOptions.add(VariantOptionDraft())),
              icon: const Icon(AppIcons.plus, size: AppSizes.s16),
              label: const Text(BusinessStrings.addVariantOption),
            ),
          ),
          Text(BusinessStrings.variantsHint, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final (index, option) in _draft.variantOptions.indexed)
            Padding(
              key: ObjectKey(option),
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Row(
                children: [
                  SizedBox(width: 110, child: TextField(controller: option.name, decoration: const InputDecoration(labelText: BusinessStrings.variantName))),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: TextField(controller: option.values, decoration: InputDecoration(labelText: BusinessStrings.variantValues, errorText: error?.call('variant_options.$index.name'))),
                  ),
                  IconButton(onPressed: () => setState(() => _draft.variantOptions.removeAt(index).dispose()), icon: const Icon(AppIcons.trash2, size: AppSizes.s18)),
                ],
              ),
            ),
          const SizedBox(height: AppSizes.s12),
        ],
        if (showTiers) ...[
          SectionTitle(
            BusinessStrings.tiersTitle,
            trailing: TextButton.icon(
              onPressed: _draft.tiers.length >= 10 ? null : () => setState(() => _draft.tiers.add(TierDraft())),
              icon: const Icon(AppIcons.plus, size: AppSizes.s16),
              label: const Text(BusinessStrings.addTier),
            ),
          ),
          Text(BusinessStrings.tiersHint(widget.baseUnit), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final (index, tier) in _draft.tiers.indexed)
            Padding(
              key: ObjectKey(tier),
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: tier.min,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                      decoration: InputDecoration(
                        labelText: BusinessStrings.tierMin(widget.baseUnit),
                        errorText: error?.call('price_tiers.$index.min_quantity'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: TextField(
                      controller: tier.price,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: BusinessStrings.tierPrice, errorText: error?.call('price_tiers.$index.price')),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _draft.tiers.removeAt(index).dispose()),
                    icon: const Icon(AppIcons.trash2, size: AppSizes.s18),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSizes.s12),
        ],
        if (showUnits) ...[
          SectionTitle(
            BusinessStrings.unitsTitle,
            trailing: TextButton.icon(
              onPressed: _draft.units.length >= 10 ? null : () => setState(() => _draft.units.add(UnitDraft())),
              icon: const Icon(AppIcons.plus, size: AppSizes.s16),
              label: const Text(BusinessStrings.addUnit),
            ),
          ),
          Text(BusinessStrings.unitsHint(widget.baseUnit), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final (index, unit) in _draft.units.indexed)
            Card(
              key: ObjectKey(unit),
              margin: const EdgeInsets.only(top: AppSpacing.s8),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: unit.name, decoration: InputDecoration(labelText: BusinessStrings.unitName, errorText: error?.call('units.$index.name')))),
                        const SizedBox(width: AppSizes.s12),
                        Expanded(
                          child: TextField(
                            controller: unit.factor,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                            decoration: InputDecoration(labelText: BusinessStrings.unitFactor(widget.baseUnit), errorText: error?.call('units.$index.factor')),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _draft.units.removeAt(index).dispose()),
                          icon: const Icon(AppIcons.trash2, size: AppSizes.s18),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: unit.price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: BusinessStrings.unitPrice))),
                        const SizedBox(width: AppSizes.s12),
                        Expanded(child: TextField(controller: unit.barcode, decoration: InputDecoration(labelText: BusinessStrings.unitBarcode, errorText: error?.call('units.$index.barcode')))),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: unit.isDefault,
                      onChanged: (value) => setState(() {
                        for (final other in _draft.units) {
                          other.isDefault = false;
                        }
                        unit.isDefault = value ?? false;
                      }),
                      title: const Text(BusinessStrings.unitDefault),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _attributeField(AttributeFieldSpec field, String? errorText) {
    final current = _draft.attributes[field.key] ?? '';

    return switch (field.type) {
      'select' => DropdownButtonFormField<String>(
          initialValue: field.options.any((option) => option.value == current) ? current : null,
          decoration: InputDecoration(labelText: field.label, errorText: errorText),
          items: [for (final option in field.options) DropdownMenuItem(value: option.value, child: Text(option.label))],
          onChanged: (value) => _draft.attributes[field.key] = value ?? '',
        ),
      'bool' => AppSwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: current == 'true' || current == '1',
          onChanged: (value) => setState(() => _draft.attributes[field.key] = value ? '1' : ''),
        ),
      _ => TextFormField(
          initialValue: current,
          keyboardType: field.type == 'number' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(labelText: field.label, hintText: field.placeholder, errorText: errorText),
          onChanged: (value) => _draft.attributes[field.key] = value,
        ),
    };
  }
}
