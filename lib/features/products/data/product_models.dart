import '../../../core/utils/json.dart';

class CategoryRecord {
  const CategoryRecord({required this.id, required this.name, this.sortOrder = 0, this.isActive = true, this.productsCount});

  factory CategoryRecord.fromJson(Map<String, dynamic> json) => CategoryRecord(
        id: json['id'] as int,
        name: json['name'] as String,
        sortOrder: asInt(json['sort_order']),
        isActive: json['is_active'] as bool? ?? true,
        productsCount: json['products_count'] == null ? null : asInt(json['products_count']),
      );

  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final int? productsCount;
}

class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.sku,
    this.barcode,
    required this.name,
    required this.unit,
    this.category,
    required this.costPrice,
    required this.price,
    required this.trackStock,
    required this.stock,
    required this.minStock,
    required this.isLowStock,
    this.imageUrl,
    required this.isActive,
  });

  factory ProductRecord.fromJson(Map<String, dynamic> json) => ProductRecord(
        id: json['id'] as int,
        sku: json['sku'] as String? ?? '',
        barcode: json['barcode'] as String?,
        name: json['name'] as String,
        unit: json['unit'] as String? ?? 'pcs',
        category: json['category'] == null ? null : CategoryRecord.fromJson(json['category'] as Map<String, dynamic>),
        costPrice: asInt(json['cost_price']),
        price: asInt(json['price']),
        trackStock: json['track_stock'] as bool? ?? false,
        stock: asDouble(json['stock']),
        minStock: asDouble(json['min_stock']),
        isLowStock: json['is_low_stock'] as bool? ?? false,
        imageUrl: json['image_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  final int id;
  final String sku;
  final String? barcode;
  final String name;
  final String unit;
  final CategoryRecord? category;
  final int costPrice;
  final int price;
  final bool trackStock;
  final double stock;
  final double minStock;
  final bool isLowStock;
  final String? imageUrl;
  final bool isActive;

  bool get isOutOfStock => trackStock && stock <= 0;
  int get margin => price - costPrice;
}

class ProductInput {
  const ProductInput({
    this.categoryId,
    this.sku,
    this.barcode,
    required this.name,
    required this.unit,
    this.costPrice,
    required this.price,
    required this.trackStock,
    this.stock,
    this.minStock,
    required this.isActive,
  });

  final int? categoryId;
  final String? sku;
  final String? barcode;
  final String name;
  final String unit;
  final int? costPrice;
  final int price;
  final bool trackStock;
  final double? stock;
  final double? minStock;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'sku': sku,
        'barcode': barcode,
        'name': name,
        'unit': unit,
        'cost_price': costPrice,
        'price': price,
        'track_stock': trackStock,
        'stock': stock,
        'min_stock': minStock,
        'is_active': isActive,
      };
}

class StockSummary {
  const StockSummary({required this.tracked, required this.low, required this.out, required this.value});

  factory StockSummary.fromJson(Map<String, dynamic> json) =>
      StockSummary(tracked: asInt(json['tracked']), low: asInt(json['low']), out: asInt(json['out']), value: asInt(json['value']));

  final int tracked;
  final int low;
  final int out;
  final int value;
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productUnit,
    required this.type,
    required this.typeLabel,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.unitCost,
    this.note,
    this.saleId,
    this.userName,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final product = asMap(json['product']);

    return StockMovement(
      id: json['id'] as int,
      productId: asInt(product['id']),
      productName: product['name'] as String? ?? '-',
      productUnit: product['unit'] as String? ?? '',
      type: json['type'] as String,
      typeLabel: json['type_label'] as String? ?? json['type'] as String,
      quantity: asDouble(json['quantity']),
      stockBefore: asDouble(json['stock_before']),
      stockAfter: asDouble(json['stock_after']),
      unitCost: json['unit_cost'] == null ? null : asInt(json['unit_cost']),
      note: json['note'] as String?,
      saleId: json['sale_id'] as int?,
      userName: asMap(json['user'])['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final int productId;
  final String productName;
  final String productUnit;
  final String type;
  final String typeLabel;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final int? unitCost;
  final String? note;
  final int? saleId;
  final String? userName;
  final DateTime createdAt;

  double get delta => stockAfter - stockBefore;
}
