import '../../../core/utils/json.dart';
import '../../pos/cart_math.dart';

class CategoryRecord {
  const CategoryRecord({required this.id, required this.name, this.sortOrder = 0, this.isActive = true, this.productsCount, this.outletIds});

  factory CategoryRecord.fromJson(Map<String, dynamic> json) => CategoryRecord(
        id: json['id'] as int,
        name: json['name'] as String,
        sortOrder: asInt(json['sort_order']),
        isActive: json['is_active'] as bool? ?? true,
        productsCount: json['products_count'] == null ? null : asInt(json['products_count']),
        outletIds: json['outlet_ids'] is List ? (json['outlet_ids'] as List).map(asInt).toList() : null,
      );

  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final int? productsCount;

  /// Outlets whose cashier shows this category; empty means every outlet, null an older server.
  final List<int>? outletIds;
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
    int? basePrice,
    this.hasOutletPrice = false,
    this.outletPrices = const {},
    this.customAttributes = const {},
    this.drugClass,
    this.drugClassLabel,
    this.requiresPrescription = false,
    this.trackBatch = false,
    this.units = const [],
    this.priceTiers = const [],
    this.trackSerial = false,
    this.warrantyDays,
    this.variantOptions = const [],
    this.parentId,
  }) : basePrice = basePrice ?? price;

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
    basePrice: json['base_price'] == null ? null : asInt(json['base_price']),
    hasOutletPrice: json['has_outlet_price'] as bool? ?? false,
    outletPrices: {
      for (final row in json['outlet_prices'] as List? ?? const [])
        if (row is Map<String, dynamic>) asInt(row['outlet_id']): asInt(row['price']),
    },
    customAttributes: asMap(json['custom_attributes']),
    drugClass: json['drug_class'] as String?,
    drugClassLabel: json['drug_class_label'] as String?,
    requiresPrescription: json['requires_prescription'] as bool? ?? false,
    trackBatch: json['track_batch'] as bool? ?? false,
    units: asList(json['units']).map(ProductUnitRecord.fromJson).toList(),
priceTiers: asList(json['price_tiers']).map(PriceTier.fromJson).toList(),
    trackSerial: json['track_serial'] as bool? ?? false,
    warrantyDays: json['warranty_days'] == null ? null : asInt(json['warranty_days']),
    variantOptions: [
      for (final option in asList(json['variant_options'])) (name: option['name'] as String? ?? '', values: (option['values'] as List? ?? const []).map((v) => '$v').toList()),
    ],
    parentId: json['parent_id'] == null ? null : asInt(json['parent_id']),
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

  /// Price of every outlet without a price of its own; `price` is what the active outlet charges.
  final int basePrice;
  final bool hasOutletPrice;

  /// Prices set for single outlets (outlet id to price); only sent with product details.
  final Map<int, int> outletPrices;

  /// Isian khusus jenis toko (zat aktif, merek, dll.) sesuai skema `meta.product_attributes`.
  final Map<String, dynamic> customAttributes;
  final String? drugClass;
  final String? drugClassLabel;
  final bool requiresPrescription;
  final bool trackBatch;
  final List<ProductUnitRecord> units;
  final List<PriceTier> priceTiers;
  final bool trackSerial;
  final int? warrantyDays;

  /// Pilihan varian di produk induk, mis. Ukuran: S, M, L.
  final List<({String name, List<String> values})> variantOptions;
  final int? parentId;

  bool get isOutOfStock => trackStock && stock <= 0;
  int get margin => price - costPrice;
}

/// Satuan jual tambahan; `factor` = isi dalam satuan dasar. `fixedPrice` null berarti faktor × harga dasar.
class ProductUnitRecord {
  const ProductUnitRecord({this.id, required this.name, required this.factor, this.price = 0, this.fixedPrice, this.barcode, this.isDefault = false});

  factory ProductUnitRecord.fromJson(Map<String, dynamic> json) => ProductUnitRecord(
        id: asInt(json['id']),
        name: json['name'] as String? ?? '',
        factor: asDouble(json['factor']),
        price: asInt(json['price']),
        fixedPrice: json['fixed_price'] == null ? null : asInt(json['fixed_price']),
        barcode: json['barcode'] as String?,
        isDefault: json['is_default_sale'] as bool? ?? false,
      );

  final int? id;
  final String name;
  final double factor;
  final int price;
  final int? fixedPrice;
  final String? barcode;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'id': ?id,
        'name': name,
        'factor': factor,
        'price': fixedPrice,
        'barcode': barcode,
        'is_default_sale': isDefault,
      };
}

/// Batch stok produk di outlet aktif.
class ProductBatchRecord {
  const ProductBatchRecord({required this.id, this.batchNumber, this.expiresAt, this.daysLeft, required this.isExpired, required this.quantity, this.productName, this.unit});

  factory ProductBatchRecord.fromJson(Map<String, dynamic> json) => ProductBatchRecord(
        id: asInt(json['id']),
        batchNumber: json['batch_number'] as String?,
        expiresAt: asDate(json['expires_at']),
        daysLeft: json['days_left'] == null ? null : asInt(json['days_left']),
        isExpired: json['is_expired'] as bool? ?? false,
        quantity: asDouble(json['quantity']),
        productName: json['product_name'] as String?,
        unit: json['unit'] as String?,
      );

  final int id;
  final String? batchNumber;
  final DateTime? expiresAt;
  final int? daysLeft;
  final bool isExpired;
  final double quantity;
  final String? productName;
  final String? unit;
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
    this.outletPrices,
    this.business,
  });

  /// Isian kapabilitas usaha; null kalau tidak ada yang menyala (field lama di server tidak diubah).
  final Map<String, dynamic>? business;

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

  /// Outlet id to its own price; null clears it so the outlet follows `price` again.
  final Map<int, int?>? outletPrices;

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
        if (outletPrices != null)
          'outlet_prices': [
            for (final entry in outletPrices!.entries) {'outlet_id': entry.key, 'price': entry.value},
          ],
        ...?business,
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
