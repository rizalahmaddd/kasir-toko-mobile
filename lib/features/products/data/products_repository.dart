import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'product_models.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) => ProductsRepository(ref.watch(apiClientProvider)));

class ProductsRepository {
  ProductsRepository(this._api);

  final ApiClient _api;

  Future<Paginated<ProductRecord>> products({String? search, int? categoryId, String? status, String? sort, int page = 1}) async {
    final body = await _api.get(
      'master-data/products',
      query: {'search': search, 'category_id': categoryId, 'status': status, 'sort': sort, 'page': page, 'per_page': 30},
    );

    return Paginated.fromJson(body, ProductRecord.fromJson);
  }

  Future<ProductRecord> product(int id) async => ProductRecord.fromJson(ApiClient.data(await _api.get('master-data/products/$id')));

  Future<ProductRecord> saveProduct(ProductInput input, {int? id}) async {
    final body = id == null ? await _api.post('master-data/products', data: input.toJson()) : await _api.put('master-data/products/$id', data: input.toJson());

    return ProductRecord.fromJson(ApiClient.data(body));
  }

  Future<void> deleteProduct(int id) => _api.delete('master-data/products/$id');

  Future<ProductRecord> uploadImage(int id, String filePath) async =>
      ProductRecord.fromJson(ApiClient.data(await _api.upload('master-data/products/$id/image', field: 'image', filePath: filePath)));

  Future<ProductRecord> deleteImage(int id) async => ProductRecord.fromJson(ApiClient.data(await _api.delete('master-data/products/$id/image')));

  Future<Paginated<CategoryRecord>> categories({String? search, int page = 1, int perPage = 50}) async {
    final body = await _api.get('master-data/categories', query: {'search': search, 'page': page, 'per_page': perPage});

    return Paginated.fromJson(body, CategoryRecord.fromJson);
  }

  Future<CategoryRecord> saveCategory({int? id, required String name, required int sortOrder, required bool isActive}) async {
    final data = {'name': name, 'sort_order': sortOrder, 'is_active': isActive};
    final body = id == null ? await _api.post('master-data/categories', data: data) : await _api.put('master-data/categories/$id', data: data);

    return CategoryRecord.fromJson(ApiClient.data(body));
  }

  Future<void> deleteCategory(int id) => _api.delete('master-data/categories/$id');

  Future<Paginated<ProductRecord>> stock({String? search, String? level, int page = 1}) async {
    final body = await _api.get('inventory/stock', query: {'search': search, 'level': level, 'page': page, 'per_page': 30});

    return Paginated.fromJson(body, ProductRecord.fromJson);
  }

  Future<StockSummary> stockSummary() async => StockSummary.fromJson(ApiClient.data(await _api.get('inventory/stock/summary')));

  Future<Paginated<StockMovement>> movements({int? productId, String? type, String? search, int page = 1}) async {
    final body = await _api.get(
      'inventory/movements',
      query: {'product_id': productId, 'type': type, 'search': search, 'page': page, 'per_page': 30},
    );

    return Paginated.fromJson(body, StockMovement.fromJson);
  }

  Future<StockMovement> adjust({required int productId, required String type, required double quantity, int? unitCost, String? note}) async {
    final body = await _api.post(
      'inventory/adjustments',
      data: {'product_id': productId, 'type': type, 'quantity': quantity, 'unit_cost': unitCost, 'note': note},
    );

    return StockMovement.fromJson(ApiClient.data(body));
  }
}
