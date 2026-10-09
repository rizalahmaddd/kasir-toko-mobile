import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

final modifierGroupsRepositoryProvider = Provider<ModifierGroupsRepository>((ref) => ModifierGroupsRepository(ref.watch(apiClientProvider)));

class ModifierOptionRecord {
  const ModifierOptionRecord({this.id, required this.name, required this.price, this.productId, this.ingredientQuantity, this.isActive = true});

  factory ModifierOptionRecord.fromJson(Map<String, dynamic> json) => ModifierOptionRecord(
        id: _int(json['id']),
        name: json['name'] as String? ?? '',
        price: _int(json['price']),
        productId: json['product_id'] == null ? null : _int(json['product_id']),
        ingredientQuantity: json['ingredient_quantity'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  final int? id;
  final String name;
  final int price;

  /// Bahan yang dipotong stoknya; diatur dari web, dikirim balik apa adanya supaya tidak hilang.
  final int? productId;
  final String? ingredientQuantity;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'id': ?id,
        'name': name,
        'price': price,
        'product_id': ?productId,
        'ingredient_quantity': ?ingredientQuantity,
        'is_active': isActive,
      };
}

class ModifierGroupRecord {
  const ModifierGroupRecord({
    required this.id,
    required this.name,
    required this.minSelect,
    this.maxSelect,
    required this.rule,
    required this.isActive,
    this.productsCount = 0,
    this.options = const [],
    this.products = const [],
  });

  factory ModifierGroupRecord.fromJson(Map<String, dynamic> json) => ModifierGroupRecord(
        id: _int(json['id']),
        name: json['name'] as String? ?? '',
        minSelect: _int(json['min_select']),
        maxSelect: json['max_select'] == null ? null : _int(json['max_select']),
        rule: json['rule'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        productsCount: _int(json['products_count']),
        options: (json['options'] as List? ?? const []).cast<Map<String, dynamic>>().map(ModifierOptionRecord.fromJson).toList(),
        products: [for (final product in (json['products'] as List? ?? const []).cast<Map<String, dynamic>>()) (id: _int(product['id']), name: product['name'] as String? ?? '')],
      );

  final int id;
  final String name;
  final int minSelect;
  final int? maxSelect;
  final String rule;
  final bool isActive;
  final int productsCount;
  final List<ModifierOptionRecord> options;
  final List<({int id, String name})> products;
}

class ModifierGroupsRepository {
  ModifierGroupsRepository(this._api);

  final ApiClient _api;

  static const _path = 'master-data/modifier-groups';

  Future<Paginated<ModifierGroupRecord>> list({String? search, int page = 1}) async =>
      Paginated.fromJson(await _api.get(_path, query: {'search': search, 'page': page, 'per_page': 30}, offlineCopy: false), ModifierGroupRecord.fromJson);

  Future<ModifierGroupRecord> show(int id) async => ModifierGroupRecord.fromJson(ApiClient.data(await _api.get('$_path/$id', offlineCopy: false)));

  Future<ModifierGroupRecord> save(Map<String, dynamic> data, {int? id}) async => ModifierGroupRecord.fromJson(
        ApiClient.data(id == null ? await _api.post(_path, data: data) : await _api.put('$_path/$id', data: data)),
      );

  Future<void> delete(int id) => _api.delete('$_path/$id');
}
