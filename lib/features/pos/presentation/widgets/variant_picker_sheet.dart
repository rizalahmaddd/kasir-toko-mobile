import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../data/pos_models.dart';

/// Pilih SKU anak dari produk induk varian.
class VariantPickerSheet extends StatelessWidget {
  const VariantPickerSheet({super.key, required this.product, required this.allowNegativeStock});

  final Product product;
  final bool allowNegativeStock;

  static Future<VariantOption?> show(BuildContext context, Product product, {required bool allowNegativeStock}) => showModalBottomSheet<VariantOption>(
        context: context,
        isScrollControlled: true,
        builder: (_) => VariantPickerSheet(product: product, allowNegativeStock: allowNegativeStock),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BottomSheetHeader(title: product.name, subtitle: PosStrings.variantSheetSubtitle),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.s16),
            children: [
              for (final variant in product.variants)
                ListTile(
                  enabled: !variant.trackStock || allowNegativeStock || variant.stock > 0,
                  title: Text(variant.label ?? variant.name),
                  subtitle: Text(variant.trackStock ? PosStrings.variantStock(quantity(variant.stock)) : PosStrings.variantUntracked),
                  trailing: Text(rupiah(variant.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.pop(context, variant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
