import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';
import '../cart_math.dart';

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class PaymentMethodOption {
  const PaymentMethodOption({required this.value, required this.label});

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) =>
      PaymentMethodOption(value: json['value'] as String, label: json['label'] as String);

  final String value;
  final String label;

  bool get isCash => value == PaymentMethods.cash;
}

class PosConfig {
  const PosConfig({
    required this.taxRate,
    required this.taxLabel,
    required this.allowNegativeStock,
    required this.allowCredit,
    required this.canDiscount,
    this.autoPrint = false,
    required this.receiptWidth,
    required this.quickCash,
    required this.paymentMethods,
    required this.qrisEnabled,
    required this.hasOpenShift,
    required this.heldOrdersCount,
    this.prescriptionMode = 'strict',
    this.canVerifyPrescription = false,
    this.serviceChargeRate = 0,
    this.serviceChargeDineInOnly = false,
    this.orderTypeEnabled = false,
    this.modifiersEnabled = false,
    this.tieredPriceEnabled = false,
    this.variantsEnabled = false,
    this.serialsEnabled = false,
    this.preOrderEnabled = false,
    this.deliveryNoteEnabled = false,
    this.nearExpiryDiscountPercent = 0,
  });

  factory PosConfig.fromJson(Map<String, dynamic> json) => PosConfig(
    taxRate: _double(json['tax_rate']),
    taxLabel: json['tax_label'] as String? ?? PosStrings.defaultTaxLabel,
    allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
    allowCredit: json['allow_credit'] as bool? ?? false,
    canDiscount: json['can_discount'] as bool? ?? false,
    autoPrint: json['auto_print'] as bool? ?? false,
    receiptWidth: '${json['receipt_width'] ?? '58'}',
    quickCash: (json['quick_cash'] as List? ?? const []).map(_int).toList(),
    paymentMethods: (json['payment_methods'] as List? ?? const []).cast<Map<String, dynamic>>().map(PaymentMethodOption.fromJson).toList(),
    qrisEnabled: json['qris_enabled'] as bool? ?? false,
    hasOpenShift: json['has_open_shift'] as bool? ?? false,
    heldOrdersCount: _int(json['held_orders_count']),
    prescriptionMode: json['prescription_mode'] as String? ?? 'strict',
    canVerifyPrescription: json['can_verify_prescription'] as bool? ?? false,
    serviceChargeRate: _double(json['service_charge_rate']),
    serviceChargeDineInOnly: json['service_charge_dine_in_only'] as bool? ?? false,
    orderTypeEnabled: json['order_type_enabled'] as bool? ?? false,
    modifiersEnabled: json['modifiers_enabled'] as bool? ?? false,
tieredPriceEnabled: json['tiered_price_enabled'] as bool? ?? false,
        variantsEnabled: json['variants_enabled'] as bool? ?? false,
        serialsEnabled: json['serials_enabled'] as bool? ?? false,
        preOrderEnabled: json['pre_order_enabled'] as bool? ?? false,
deliveryNoteEnabled: json['delivery_note_enabled'] as bool? ?? false,
        nearExpiryDiscountPercent: _double(json['near_expiry_discount_percent']),
      );

  final double taxRate;
  final String taxLabel;
  final bool allowNegativeStock;
  final bool allowCredit;
  final bool canDiscount;
  final bool autoPrint;
  final String receiptWidth;
  final List<int> quickCash;
  final List<PaymentMethodOption> paymentMethods;
  final bool qrisEnabled;
  final bool hasOpenShift;
  final int heldOrdersCount;
  final String prescriptionMode;
  final bool canVerifyPrescription;
  final double serviceChargeRate;
  final bool serviceChargeDineInOnly;
  final bool orderTypeEnabled;
  final bool modifiersEnabled;
  final bool tieredPriceEnabled;
  final bool variantsEnabled;
  final bool serialsEnabled;
  final bool preOrderEnabled;
  final bool deliveryNoteEnabled;

  /// Potongan (persen) untuk unit dari batch hampir kedaluwarsa; 0 berarti mati.
  final double nearExpiryDiscountPercent;

  /// Persen service charge untuk tipe pesanan ini (0 bila tidak dipungut).
  double serviceRateFor(String? orderType) {
    if (serviceChargeRate <= 0) {
      return 0;
    }

    return serviceChargeDineInOnly && orderType != OrderTypes.dineIn ? 0 : serviceChargeRate;
  }

  bool get strictPrescription => prescriptionMode != 'warn';

  /// Resep boleh diisi langsung di kasir: mode peringatan, atau kasirnya apoteker.
  bool get canDraftPrescription => !strictPrescription || canVerifyPrescription;
}

/// Satuan jual tambahan; `factor` = isi dalam satuan dasar produk, `price` sudah harga outlet aktif.
class ProductUnitOption {
  const ProductUnitOption({required this.id, required this.name, required this.factor, required this.price, this.isDefault = false});

  factory ProductUnitOption.fromJson(Map<String, dynamic> json) => ProductUnitOption(
        id: _int(json['id']),
        name: json['name'] as String? ?? '',
        factor: _double(json['factor']),
        price: _int(json['price']),
        isDefault: json['is_default_sale'] as bool? ?? json['default'] as bool? ?? false,
      );

  final int id;
  final String name;
  final double factor;
  final int price;
  final bool isDefault;

  /// Kunci yang sama dengan keranjang web supaya transaksi tertunda bisa dilanjutkan di perangkat mana pun.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'factor': factor, 'price': price, 'default': isDefault};
}

abstract final class OrderTypes {
  static const dineIn = 'dine_in';
  static const takeAway = 'take_away';
  static const delivery = 'delivery';

  static const all = [dineIn, takeAway, delivery];
}

class VariantOption {
  const VariantOption({required this.id, required this.name, this.label, this.sku, this.barcode, required this.price, required this.stock, this.trackStock = true, this.trackSerial = false});

  factory VariantOption.fromJson(Map<String, dynamic> json) => VariantOption(
        id: _int(json['id']),
        name: json['name'] as String? ?? '',
        label: json['label'] as String?,
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        price: _int(json['price']),
        stock: _double(json['stock']),
        trackStock: json['track_stock'] as bool? ?? true,
        trackSerial: json['track_serial'] as bool? ?? false,
      );

  final int id;
  final String name;
  final String? label;
  final String? sku;
  final String? barcode;
  final int price;
  final double stock;
  final bool trackStock;
  final bool trackSerial;
}

class ModifierOption {
  const ModifierOption({required this.id, required this.name, required this.price});

  factory ModifierOption.fromJson(Map<String, dynamic> json) =>
      ModifierOption(id: _int(json['id']), name: json['name'] as String? ?? '', price: _int(json['price']));

  final int id;
  final String name;
  final int price;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
}

/// Grup pilihan tambahan; [min] > 0 berarti wajib, [max] null berarti bebas.
class ModifierGroupOption {
  const ModifierGroupOption({required this.id, required this.name, required this.min, this.max, required this.rule, required this.modifiers});

  factory ModifierGroupOption.fromJson(Map<String, dynamic> json) => ModifierGroupOption(
    id: _int(json['id']),
    name: json['name'] as String? ?? '',
    min: _int(json['min']),
    max: json['max'] == null ? null : _int(json['max']),
    rule: json['rule'] as String? ?? '',
    modifiers: (json['modifiers'] as List? ?? const []).cast<Map<String, dynamic>>().map(ModifierOption.fromJson).toList(),
  );

  final int id;
  final String name;
  final int min;
  final int? max;
  final String rule;
  final List<ModifierOption> modifiers;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'min': min, 'max': max, 'rule': rule, 'modifiers': modifiers.map((m) => m.toJson()).toList()};
}

/// Pilihan yang dipilih di satu baris keranjang (snapshot nama & harga saat dipilih).
class SelectedModifier {
  const SelectedModifier({required this.id, required this.name, required this.price, this.group});

  factory SelectedModifier.fromJson(Map<String, dynamic> json) =>
      SelectedModifier(id: _int(json['id']), name: json['name'] as String? ?? '', price: _int(json['price']), group: json['group'] as String?);

  final int id;
  final String name;
  final int price;
  final String? group;

  SelectedModifier withPrice(int value) => SelectedModifier(id: id, name: name, price: value, group: group);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'group': ?group};
}

List<PriceTier> _tiers(dynamic value) => (value as List? ?? const []).cast<Map<String, dynamic>>().map(PriceTier.fromJson).toList();

List<ModifierGroupOption> _groups(dynamic value) => (value as List? ?? const []).cast<Map<String, dynamic>>().map(ModifierGroupOption.fromJson).toList();

class Category {
  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) => Category(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.unit,
    required this.price,
    required this.trackStock,
    required this.stock,
    this.isLowStock = false,
    this.categoryName,
    this.categoryId,
    this.imageUrl,
    this.units = const [],
    this.requiresPrescription = false,
    this.drugClassLabel,
    this.matchedUnitId,
    this.tiers = const [],
    this.modifierGroups = const [],
    this.variants = const [],
    this.trackSerial = false,
    this.matchedSerial,
    this.variantLabel,
    this.nearExpiry = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as int,
    name: json['name'] as String,
    sku: json['sku'] as String?,
    barcode: json['barcode'] as String?,
    unit: json['unit'] as String? ?? PosStrings.defaultUnit,
    price: _int(json['price']),
    trackStock: json['track_stock'] as bool? ?? false,
    stock: _double(json['stock']),
    isLowStock: json['is_low_stock'] as bool? ?? false,
    categoryName: (json['category'] as Map<String, dynamic>?)?['name'] as String?,
    categoryId: (json['category'] as Map<String, dynamic>?)?['id'] as int?,
    imageUrl: json['image_url'] as String?,
    units: (json['units'] as List? ?? const []).cast<Map<String, dynamic>>().map(ProductUnitOption.fromJson).toList(),
    requiresPrescription: json['requires_prescription'] as bool? ?? false,
    drugClassLabel: json['drug_class_label'] as String?,
    matchedUnitId: json['matched_unit_id'] == null ? null : _int(json['matched_unit_id']),
        tiers: _tiers(json['price_tiers']),
        modifierGroups: _groups(json['modifier_groups']),
        variants: (json['variants'] as List? ?? const []).cast<Map<String, dynamic>>().map(VariantOption.fromJson).toList(),
        trackSerial: json['track_serial'] as bool? ?? false,
        matchedSerial: json['matched_serial'] as String?,
variantLabel: json['variant_label'] as String?,
        nearExpiry: _double(json['near_expiry_quantity']),
      );

  final int id;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final int price;
  final bool trackStock;
  final double stock;
  final bool isLowStock;
  final String? categoryName;
  final int? categoryId;
  final String? imageUrl;
  final List<ProductUnitOption> units;
  final bool requiresPrescription;
  final String? drugClassLabel;

  /// Satuan yang barcodenya baru saja discan (dari lookup), dipilih otomatis di keranjang.
  final int? matchedUnitId;
  final List<PriceTier> tiers;
  final List<ModifierGroupOption> modifierGroups;

  /// SKU anak; produk induk tidak bisa dijual langsung.
  final List<VariantOption> variants;
  final bool trackSerial;

  /// Nomor seri yang cocok dengan hasil scan (lookup), langsung dipilih di keranjang.
  final String? matchedSerial;
  final String? variantLabel;

  /// Unit dari batch hampir kedaluwarsa di outlet aktif yang mendapat potongan ED dekat.
  final double nearExpiry;

  /// SKU anak sebagai produk keranjang; satuan, grosir, dan pilihan tambahan induk tidak berlaku untuk anak.
  Product variantProduct(VariantOption variant) => Product(
        id: variant.id,
        name: variant.name,
        sku: variant.sku,
        barcode: variant.barcode,
        unit: unit,
        price: variant.price,
        trackStock: variant.trackStock,
        stock: variant.stock,
        categoryName: categoryName,
        categoryId: categoryId,
        imageUrl: imageUrl,
        trackSerial: variant.trackSerial,
        variantLabel: variant.label,
      );

  bool get isOutOfStock => trackStock && stock <= 0;

  ProductUnitOption? unitById(int? id) => id == null ? null : units.where((unit) => unit.id == id).firstOrNull;

  ProductUnitOption? get defaultUnit => units.where((unit) => unit.isDefault).firstOrNull;
}

class CustomerOption {
const CustomerOption({required this.id, required this.name, this.code, this.phone, this.due = 0, this.creditLimit});

  factory CustomerOption.fromJson(Map<String, dynamic> json) => CustomerOption(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String?,
        phone: json['phone'] as String?,
        due: _int(json['due']),
        creditLimit: json['credit_limit'] == null ? null : _int(json['credit_limit']),
      );

  final int id;
  final String name;
  final String? code;
  final String? phone;
  final int due;

  /// Batas total kasbon; null berarti tanpa batas.
  final int? creditLimit;

  /// Sisa kasbon yang masih boleh dicatat, null bila tanpa batas.
  int? get creditRoom => creditLimit == null ? null : (creditLimit! - due).clamp(0, creditLimit!);
}

class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    this.sku,
    required this.unit,
    required this.price,
    required this.quantity,
    this.discount = 0,
    this.note,
    required this.trackStock,
    required this.stock,
    this.imageUrl,
    this.unitId,
    this.factor = 1,
    this.baseUnit,
    this.basePrice,
    this.units = const [],
    this.requiresPrescription = false,
    this.modifiers = const [],
    this.tiers = const [],
    this.modifierGroups = const [],
    this.tierPrice,
    this.trackSerial = false,
    this.serials = const [],
    this.nearExpiry = 0,
    this.autoDiscount = 0,
  });

  factory CartItem.fromProduct(
    Product product, {
    double quantity = 1,
    ProductUnitOption? unit,
    bool withUnits = true,
    List<SelectedModifier> modifiers = const [],
    bool withTiers = true,
    bool withModifiers = true,
    List<String> serials = const [],
  }) => CartItem(
    productId: product.id,
    name: product.name,
    sku: product.sku,
    unit: unit?.name ?? product.unit,
    price: unit?.price ?? product.price,
    quantity: quantity,
    trackStock: product.trackStock,
    stock: product.stock,
    imageUrl: product.imageUrl,
    unitId: unit?.id,
    factor: unit?.factor ?? 1,
    baseUnit: product.unit,
    basePrice: product.price,
    units: withUnits ? product.units : const [],
    requiresPrescription: product.requiresPrescription,
    modifiers: modifiers,
tiers: withTiers ? product.tiers : const [],
        modifierGroups: withModifiers ? product.modifierGroups : const [],
trackSerial: product.trackSerial,
        serials: serials,
        nearExpiry: product.nearExpiry,
      );

  /// Same keys as the web cashier's cart so held orders resume on either device.
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: _int(json['product_id']),
    name: json['name'] as String? ?? '',
    sku: json['sku'] as String?,
    unit: json['unit'] as String? ?? PosStrings.defaultUnit,
    price: _int(json['price']),
    quantity: _double(json['quantity']),
    discount: _int(json['discount']),
    note: json['note'] as String?,
    trackStock: json['track'] as bool? ?? false,
    stock: _double(json['stock']),
    imageUrl: json['image_url'] as String?,
    unitId: json['unit_id'] == null ? null : _int(json['unit_id']),
    factor: json['factor'] == null ? 1 : _double(json['factor']),
    baseUnit: json['base_unit'] as String?,
    basePrice: json['base_price'] == null ? null : _int(json['base_price']),
    units: (json['units'] as List? ?? const []).cast<Map<String, dynamic>>().map(ProductUnitOption.fromJson).toList(),
    requiresPrescription: json['rx'] as bool? ?? false,
    modifiers: (json['modifiers'] as List? ?? const []).cast<Map<String, dynamic>>().map(SelectedModifier.fromJson).toList(),
        tiers: _tiers(json['tiers']),
        modifierGroups: _groups(json['modifier_groups']),
        trackSerial: json['serial'] as bool? ?? false,
serials: (json['serials'] as List? ?? const []).map((s) => '$s').toList(),
        nearExpiry: _double(json['near_expiry']),
      );

  final int productId;
  final String name;
  final String? sku;
  final String unit;

  /// Harga satuan sebelum harga grosir (untuk satuan dasar) dan tanpa pilihan tambahan.
  final int price;
  final double quantity;
  final int discount;
  final String? note;
  final bool trackStock;
  final double stock;
  final String? imageUrl;
  final int? unitId;

  /// Isi satu satuan baris ini dalam satuan dasar produk; stok selalu dihitung dalam satuan dasar.
  final double factor;
  final String? baseUnit;
  final int? basePrice;
  final List<ProductUnitOption> units;
  final bool requiresPrescription;
  final List<SelectedModifier> modifiers;
  final List<PriceTier> tiers;
  final List<ModifierGroupOption> modifierGroups;

  /// Harga grosir yang sedang berlaku, diisi keranjang dari jumlah semua baris satuan dasar produk ini.
  final int? tierPrice;
  final bool trackSerial;

  /// Nomor seri unit yang diserahkan; jumlahnya harus sama dengan quantity.
  final List<String> serials;
  final double nearExpiry;

  /// Potongan ED dekat baris ini, diisi keranjang (unit ED dekat dibagi berurutan antarbaris produk yang sama).
  final int autoDiscount;

  bool get needsSerials => trackSerial && serials.length != quantity.round();

  /// Satu produk boleh muncul di beberapa baris dengan satuan atau pilihan tambahan berbeda.
  String get key => '$productId:${unitId ?? 0}:$modifierKey';

  String get modifierKey => (modifiers.map((m) => m.id).toList()..sort()).join('-');

  String get signature => lineSignature(productId: productId, unitId: unitId, modifierIds: modifiers.map((m) => m.id), note: note);

  double get baseQuantity => quantity * factor;

  int get modifiersTotal => modifiers.fold(0, (sum, m) => sum + m.price);

  String get modifierNames => modifiers.map((m) => m.name).join(', ');

  /// Harga satuan yang dikirim ke server (sudah harga grosir bila berlaku).
  int get unitPrice => unitId == null ? tierPrice ?? price : price;

  bool get isTiered => unitId == null && tierPrice != null && tierPrice! < price;

  int get gross => ((unitPrice + modifiersTotal) * quantity).round();

int get appliedDiscount => (discount + autoDiscount).clamp(0, gross);

  int get total => gross - appliedDiscount;

  bool get exceedsStock => trackStock && baseQuantity > stock;

  CartItem copyWith({
    int? price,
    double? quantity,
    int? discount,
    String? note,
    bool clearNote = false,
    double? stock,
    String? imageUrl,
    List<ProductUnitOption>? units,
    bool? requiresPrescription,
    int? basePrice,
    List<SelectedModifier>? modifiers,
    List<PriceTier>? tiers,
    List<ModifierGroupOption>? modifierGroups,
    int? tierPrice,
    bool clearTierPrice = false,
    List<String>? serials,
    double? nearExpiry,
    int? autoDiscount,
  }) =>
      CartItem(
    productId: productId,
    name: name,
    sku: sku,
    unit: unit,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    discount: discount ?? this.discount,
    note: clearNote ? null : note ?? this.note,
    trackStock: trackStock,
    stock: stock ?? this.stock,
    imageUrl: imageUrl ?? this.imageUrl,
    unitId: unitId,
    factor: factor,
    baseUnit: baseUnit,
    basePrice: basePrice ?? this.basePrice,
    units: units ?? this.units,
    requiresPrescription: requiresPrescription ?? this.requiresPrescription,
    modifiers: modifiers ?? this.modifiers,
    tiers: tiers ?? this.tiers,
    modifierGroups: modifierGroups ?? this.modifierGroups,
tierPrice: clearTierPrice ? null : tierPrice ?? this.tierPrice,
        trackSerial: trackSerial,
serials: serials ?? this.serials,
        nearExpiry: nearExpiry ?? this.nearExpiry,
        autoDiscount: autoDiscount ?? this.autoDiscount,
      );

  /// Pindah satuan: harga & faktor ikut satuan baru; null kembali ke satuan dasar.
  CartItem withUnit(ProductUnitOption? option) => CartItem(
    productId: productId,
    name: name,
    sku: sku,
    unit: option?.name ?? baseUnit ?? unit,
    price: option?.price ?? basePrice ?? price,
    quantity: quantity,
    discount: discount,
    note: note,
    trackStock: trackStock,
    stock: stock,
    imageUrl: imageUrl,
    unitId: option?.id,
    factor: option?.factor ?? 1,
    baseUnit: baseUnit,
    basePrice: basePrice,
    units: units,
    requiresPrescription: requiresPrescription,
        modifiers: modifiers,
        tiers: tiers,
        modifierGroups: modifierGroups,
        trackSerial: trackSerial,
        serials: serials,
        nearExpiry: nearExpiry,
      );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'sku': sku,
    'unit': unit,
    'price': price,
    'quantity': quantity,
    'discount': discount,
    'note': note,
    'track': trackStock,
    'stock': stock,
    if (imageUrl != null) 'image_url': imageUrl,
    'unit_id': unitId,
    'factor': factor,
    'base_unit': ?baseUnit,
    'base_price': ?basePrice,
    if (units.isNotEmpty) 'units': units.map((unit) => unit.toJson()).toList(),
    'rx': requiresPrescription,
    'modifiers': modifiers.map((m) => m.toJson()).toList(),
    if (tiers.isNotEmpty) 'tiers': tiers.map((t) => t.toJson()).toList(),
if (modifierGroups.isNotEmpty) 'modifier_groups': modifierGroups.map((g) => g.toJson()).toList(),
        if (trackSerial) 'serial': true,
        if (serials.isNotEmpty) 'serials': serials,
        if (nearExpiry > 0) 'near_expiry': nearExpiry,
      };

  Map<String, dynamic> toCheckoutJson() => {
    'product_id': productId,
    'unit_id': ?unitId,
    'quantity': quantity,
    'price': unitPrice,
        'discount': discount,
        if (autoDiscount > 0) 'auto_discount': autoDiscount,
        'note': note,
        if (modifiers.isNotEmpty) 'modifiers': modifiers.map((m) => {'id': m.id, 'name': m.name, 'price': m.price}).toList(),
        if (trackSerial) 'serials': serials,
      };
}

enum DiscountType { percent, amount }

class CartTotals {
  const CartTotals({required this.subtotal, required this.discountAmount, required this.taxAmount, required this.total, this.serviceAmount = 0});

  /// Mirrors App\Services\Pos\CartCalculator so the screen total matches what the server stores.
  factory CartTotals.calculate(List<CartItem> items, DiscountType? discountType, double discountValue, double taxRate, {double serviceRate = 0}) {
    final result = calculateCart(
      [for (final item in items)MathLine(price: item.unitPrice, quantity: item.quantity, discount: item.discount + item.autoDiscount, modifiers: item.modifiersTotal)],
      discountType?.name,
      discountValue,
      taxRate,
      serviceRate: serviceRate,
    );

    return CartTotals(
      subtotal: result.subtotal,
      discountAmount: result.discountAmount,
      serviceAmount: result.serviceAmount,
      taxAmount: result.taxAmount,
      total: result.total,
    );
  }

  final int subtotal;
  final int discountAmount;
  final int serviceAmount;
  final int taxAmount;
  final int total;
}

class Cart {
  const Cart({
    required this.clientUuid,
    this.items = const [],
    this.customer,
    this.discountType,
    this.discountValue = 0,
    this.note,
    this.prescription,
    this.prescriptionDraft,
    this.orderType,
    this.table,
    this.kitchenSent = const {},
    this.customerOrder,
  });

  factory Cart.fromJson(Map<String, dynamic> json, {required String fallbackUuid}) {
    final customer = json['customer'] as Map<String, dynamic>?;

    return Cart(
      clientUuid: json['client_uuid'] as String? ?? fallbackUuid,
      items: (json['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(CartItem.fromJson).toList(),
      customer: customer?['id'] == null ? null : CustomerOption(id: _int(customer!['id']), name: customer['name'] as String? ?? ''),
      discountType: switch (json['discountType']) {
        DiscountTypes.percent => DiscountType.percent,
        DiscountTypes.amount => DiscountType.amount,
        _ => null,
      },
      discountValue: _double(json['discountValue']),
      note: json['note'] as String?,
      prescription: json['prescription'] is Map<String, dynamic> ? LinkedPrescription.fromJson(json['prescription'] as Map<String, dynamic>) : null,
      prescriptionDraft: json['prescriptionDraft'] is Map<String, dynamic>
          ? PrescriptionDraft.fromJson(json['prescriptionDraft'] as Map<String, dynamic>)
          : null,
      orderType: json['orderType'] as String?,
      table: json['table'] as String?,
kitchenSent: {for (final entry in (json['kitchenSent'] is Map ? json['kitchenSent'] as Map : const {}).entries) '${entry.key}': _double(entry.value)},
      customerOrder: json['customerOrder'] is Map<String, dynamic> ? LinkedOrder.fromJson(json['customerOrder'] as Map<String, dynamic>) : null,
    );
  }

  final String clientUuid;
  final List<CartItem> items;
  final CustomerOption? customer;
  final DiscountType? discountType;
  final double discountValue;
  final String? note;
  final LinkedPrescription? prescription;
  final PrescriptionDraft? prescriptionDraft;
  final String? orderType;
  final String? table;

  /// Jumlah per penanda baris yang sudah dikirim ke dapur (dari open bill), dibawa bolak-balik ke server.
  final Map<String, double> kitchenSent;

  /// Pesanan yang sedang dilunasi; uang mukanya dipotong dari total.
  final LinkedOrder? customerOrder;

  /// Yang masih harus dibayar di kasir: total dikurangi uang muka pesanan.
  int amountDue(PosConfig? config) {
    final total = totalsFor(config).total;
    final deposit = customerOrder?.deposit ?? 0;

    return total > deposit ? total - deposit : 0;
  }

  bool get isEmpty => items.isEmpty;

  bool get needsPrescription => items.any((item) => item.requiresPrescription);

  bool get hasPrescription => prescription != null || prescriptionDraft != null;

  double get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartTotals totals(double taxRate, {double serviceRate = 0}) => CartTotals.calculate(items, discountType, discountValue, taxRate, serviceRate: serviceRate);

  CartTotals totalsFor(PosConfig? config) => totals(config?.taxRate ?? 0, serviceRate: config?.serviceRateFor(orderTypeFor(config)) ?? 0);

  /// Tipe pesanan yang berlaku: makan di tempat bila kasir belum memilih, null bila fiturnya mati.
  String? orderTypeFor(PosConfig? config) => (config?.orderTypeEnabled ?? false) ? orderType ?? OrderTypes.dineIn : null;

  Cart copyWith({
    String? clientUuid,
    List<CartItem>? items,
    CustomerOption? customer,
    bool clearCustomer = false,
    DiscountType? discountType,
    double? discountValue,
    bool clearDiscount = false,
    String? note,
    LinkedPrescription? prescription,
    PrescriptionDraft? prescriptionDraft,
    bool clearPrescription = false,
    String? orderType,
    String? table,
    bool clearTable = false,
    Map<String, double>? kitchenSent,
    LinkedOrder? customerOrder,
    bool clearCustomerOrder = false,
  }) => Cart(
    clientUuid: clientUuid ?? this.clientUuid,
    items: items ?? this.items,
    customer: clearCustomer ? null : customer ?? this.customer,
    discountType: clearDiscount ? null : discountType ?? this.discountType,
    discountValue: clearDiscount ? 0 : discountValue ?? this.discountValue,
    note: note ?? this.note,
    prescription: clearPrescription ? null : prescription ?? this.prescription,
    prescriptionDraft: clearPrescription ? null : prescriptionDraft ?? this.prescriptionDraft,
    orderType: orderType ?? this.orderType,
    table: clearTable ? null : table ?? this.table,
kitchenSent: kitchenSent ?? this.kitchenSent,
        customerOrder: clearCustomerOrder ? null : customerOrder ?? this.customerOrder,
      );

  Map<String, dynamic> toJson({int? total}) => {
    'client_uuid': clientUuid,
    'items': items.map((item) => item.toJson()).toList(),
    'customer': customer == null ? null : {'id': customer!.id, 'name': customer!.name},
    'discountType': discountType?.name,
    'discountValue': discountValue,
    'note': note,
    'prescription': prescription?.toJson(),
    'prescriptionDraft': prescriptionDraft?.toJson(),
    'orderType': ?orderType,
    if (table != null && table!.isNotEmpty) 'table': table,
if (kitchenSent.isNotEmpty) 'kitchenSent': kitchenSent,
        'customerOrder': ?customerOrder?.toJson(),
    'total': ?total,
  };
}

/// Pesanan (pre-order/servis) yang dilunasi lewat keranjang ini.
class LinkedOrder {
  const LinkedOrder({required this.id, required this.number, required this.deposit});

  factory LinkedOrder.fromJson(Map<String, dynamic> json) => LinkedOrder(id: _int(json['id']), number: json['number'] as String? ?? '', deposit: _int(json['deposit']));

  final int id;
  final String number;
  final int deposit;

  Map<String, dynamic> toJson() => {'id': id, 'number': number, 'deposit': deposit};
}

/// Resep tersimpan yang ditautkan ke keranjang.
class LinkedPrescription {
  const LinkedPrescription({required this.id, required this.number, required this.patient});

  factory LinkedPrescription.fromJson(Map<String, dynamic> json) =>
      LinkedPrescription(id: _int(json['id']), number: json['number'] as String? ?? '', patient: json['patient'] as String? ?? '');

  final int id;
  final String number;
  final String patient;

  Map<String, dynamic> toJson() => {'id': id, 'number': number, 'patient': patient};
}

/// Dokter & pasien yang diisi langsung di kasir; server membuat resepnya saat checkout.
class PrescriptionDraft {
  const PrescriptionDraft({required this.doctorName, required this.patientName, this.patientAge, this.doctorSip, this.clinicName});

  factory PrescriptionDraft.fromJson(Map<String, dynamic> json) => PrescriptionDraft(
        doctorName: json['doctor_name'] as String? ?? '',
        patientName: json['patient_name'] as String? ?? '',
        patientAge: json['patient_age'] == null ? null : _int(json['patient_age']),
        doctorSip: json['doctor_sip'] as String?,
        clinicName: json['clinic_name'] as String?,
      );

  final String doctorName;
  final String patientName;
  final int? patientAge;
  final String? doctorSip;
  final String? clinicName;

  Map<String, dynamic> toJson() => {
        'doctor_name': doctorName,
        'patient_name': patientName,
        'patient_age': ?patientAge,
        if (doctorSip != null && doctorSip!.isNotEmpty) 'doctor_sip': doctorSip,
        if (clinicName != null && clinicName!.isNotEmpty) 'clinic_name': clinicName,
      };
}

class HeldOrder {
  const HeldOrder({
    required this.id,
    this.label,
    required this.itemCount,
    required this.total,
    required this.createdAt,
    this.cart,
    this.tableLabel,
    this.isMine = true,
    this.kitchenTicketId,
  });

  factory HeldOrder.fromJson(Map<String, dynamic> json) => HeldOrder(
    id: json['id'] as int,
    label: json['label'] as String?,
    itemCount: _double(json['item_count']),
    total: _int(json['total']),
    createdAt: DateTime.parse(json['created_at'] as String),
    cart: json['cart'] as Map<String, dynamic>?,
    tableLabel: json['table_label'] as String?,
    isMine: json['is_mine'] as bool? ?? true,
  );

  final int id;
  final String? label;
  final double itemCount;
  final int total;
  final DateTime createdAt;
  final Map<String, dynamic>? cart;

  /// Open bill meja: terlihat semua kasir di outlet itu.
  final String? tableLabel;
  final bool isMine;

  /// Tiket dapur yang baru dibuat saat transaksi ini ditunda (hanya di respons tunda).
  final int? kitchenTicketId;

  HeldOrder withKitchenTicket(int? id) => HeldOrder(id: this.id, label: label, itemCount: itemCount, total: total, createdAt: createdAt, cart: cart, tableLabel: tableLabel, isMine: isMine, kitchenTicketId: id);
}

class QrisPayment {
  const QrisPayment({required this.payload, required this.amount, this.merchantName});

  factory QrisPayment.fromJson(Map<String, dynamic> json) => QrisPayment(
        payload: json['payload'] as String,
        amount: _int(json['amount']),
        merchantName: json['merchant_name'] as String?,
      );

  final String payload;
  final int amount;
  final String? merchantName;
}

class PaymentLine {
  const PaymentLine({required this.method, required this.amount, this.reference});

  final String method;
  final int amount;
  final String? reference;

  Map<String, dynamic> toJson() => {'method': method, 'amount': amount, 'reference': reference};
}
