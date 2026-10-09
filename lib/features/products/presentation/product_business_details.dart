import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/product_meta.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';

final _batchesProvider = FutureProvider.autoDispose.family<List<ProductBatchRecord>, int>((ref, id) => ref.read(productsRepositoryProvider).batches(id));

/// Ringkasan isian kapabilitas usaha di detail produk: golongan obat, atribut, satuan, dan batch.
class ProductBusinessDetails extends ConsumerWidget {
  const ProductBusinessDetails({super.key, required this.product});

  final ProductRecord product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final meta = ref.watch(productMetaProvider).value ?? const ProductMeta();
    final attributes = [
      for (final field in meta.attributes)
        if ('${product.customAttributes[field.key] ?? ''}'.isNotEmpty)
          (field.label, field.options.where((option) => option.value == '${product.customAttributes[field.key]}').firstOrNull?.label ?? '${product.customAttributes[field.key]}'),
    ];
    final showPharmacy = (user?.usesPrescriptions ?? false) && (product.drugClass != null || product.requiresPrescription);
    final showUnits = (user?.usesMultiUnit ?? false) && product.units.isNotEmpty;
    final showBatches = (user?.usesBatches ?? false) && product.trackBatch && product.trackStock;

    if (attributes.isEmpty && !showPharmacy && !showUnits && !showBatches) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(BusinessStrings.sectionTitle),
        if (showPharmacy) ...[
          if (product.drugClassLabel != null) InfoRow(BusinessStrings.drugClass, product.drugClassLabel!),
          if (product.requiresPrescription) const Align(alignment: Alignment.centerLeft, child: StatusBadge(label: 'WAJIB RESEP', tone: BadgeTone.danger)),
        ],
        for (final (label, value) in attributes) InfoRow(label, value),
        if (showUnits)
          for (final unit in product.units) InfoRow('${unit.name} (${quantity(unit.factor)} ${product.unit})', rupiah(unit.price)),
        if (showBatches) ...[
          const SectionTitle(BusinessStrings.batchesTitle),
          AsyncView<List<ProductBatchRecord>>(
            value: ref.watch(_batchesProvider(product.id)),
            data: (batches) => Column(
              children: [
                for (final batch in batches)
                  InfoRow(
                    [batch.batchNumber ?? BusinessStrings.noBatchNumber, if (batch.expiresAt != null) 'ED ${dateOnly(batch.expiresAt!)}'].join(' · '),
                    '${quantity(batch.quantity)} ${product.unit}${batch.daysLeft == null ? '' : ' · ${BusinessStrings.expiresIn(batch.daysLeft!)}'}',
                    valueColor: batch.isExpired ? Theme.of(context).colorScheme.error : null,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
