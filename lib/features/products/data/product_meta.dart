import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';

class AttributeOption {
  const AttributeOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// Satu isian atribut produk dari skema jenis toko (`meta.product_attributes`).
class AttributeFieldSpec {
  const AttributeFieldSpec({required this.key, required this.label, required this.type, this.options = const [], this.required = false, this.placeholder});

  factory AttributeFieldSpec.fromJson(Map<String, dynamic> json) => AttributeFieldSpec(
        key: json['key'] as String,
        label: json['label'] as String? ?? json['key'] as String,
        type: json['type'] as String? ?? 'text',
        options: [
          for (final option in json['options'] as List? ?? const [])
            if (option is Map<String, dynamic>) AttributeOption(value: '${option['value']}', label: '${option['label']}'),
        ],
        required: json['required'] as bool? ?? false,
        placeholder: json['placeholder'] as String?,
      );

  final String key;
  final String label;
  final String type;
  final List<AttributeOption> options;
  final bool required;
  final String? placeholder;
}

class ProductMeta {
  const ProductMeta({this.attributes = const [], this.units = const [], this.drugClasses = const {}});

  factory ProductMeta.fromJson(Map<String, dynamic> json) {
    final enums = json['enums'] as Map<String, dynamic>? ?? const {};

    return ProductMeta(
      attributes: [for (final field in json['product_attributes'] as List? ?? const []) if (field is Map<String, dynamic>) AttributeFieldSpec.fromJson(field)],
      units: (enums['product_units'] as Map<String, dynamic>? ?? const {}).keys.toList(),
      drugClasses: (enums['drug_classes'] as Map<String, dynamic>? ?? const {}).map((key, value) => MapEntry(key, '$value')),
    );
  }

  final List<AttributeFieldSpec> attributes;
  final List<String> units;
  final Map<String, String> drugClasses;
}

const _cacheKey = 'product_meta';

/// Skema isian produk toko ini; disimpan supaya form produk tetap lengkap saat offline.
final productMetaProvider = FutureProvider<ProductMeta>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  try {
    final data = ApiClient.data(await ref.watch(apiClientProvider).get(ApiEndpoints.meta));
    await prefs.setString(_cacheKey, jsonEncode(data));
    return ProductMeta.fromJson(data);
  } on Object {
    final cached = prefs.getString(_cacheKey);
    return cached == null ? const ProductMeta() : ProductMeta.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }
});
