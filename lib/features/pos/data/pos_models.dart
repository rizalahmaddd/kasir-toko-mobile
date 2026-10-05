import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';

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
        paymentMethods: (json['payment_methods'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(PaymentMethodOption.fromJson)
            .toList(),
        qrisEnabled: json['qris_enabled'] as bool? ?? false,
        hasOpenShift: json['has_open_shift'] as bool? ?? false,
        heldOrdersCount: _int(json['held_orders_count']),
        prescriptionMode: json['prescription_mode'] as String? ?? 'strict',
        canVerifyPrescription: json['can_verify_prescription'] as bool? ?? false,
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

  bool get isOutOfStock => trackStock && stock <= 0;

  ProductUnitOption? unitById(int? id) => id == null ? null : units.where((unit) => unit.id == id).firstOrNull;

  ProductUnitOption? get defaultUnit => units.where((unit) => unit.isDefault).firstOrNull;
}

class CustomerOption {
  const CustomerOption({required this.id, required this.name, this.code, this.phone, this.due = 0});

  factory CustomerOption.fromJson(Map<String, dynamic> json) => CustomerOption(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String?,
        phone: json['phone'] as String?,
        due: _int(json['due']),
      );

  final int id;
  final String name;
  final String? code;
  final String? phone;
  final int due;
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
  });

  factory CartItem.fromProduct(Product product, {double quantity = 1, ProductUnitOption? unit, bool withUnits = true}) => CartItem(
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
      );

  final int productId;
  final String name;
  final String? sku;
  final String unit;
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

  /// Satu produk boleh muncul di beberapa baris dengan satuan berbeda.
  String get key => '$productId:${unitId ?? 0}';

  double get baseQuantity => quantity * factor;

  int get gross => (price * quantity).round();

  int get appliedDiscount => discount.clamp(0, gross);

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
      };

  Map<String, dynamic> toCheckoutJson() => {
        'product_id': productId,
        'unit_id': ?unitId,
        'quantity': quantity,
        'price': price,
        'discount': discount,
        'note': note,
      };
}

enum DiscountType { percent, amount }

class CartTotals {
  const CartTotals({required this.subtotal, required this.discountAmount, required this.taxAmount, required this.total});

  /// Mirrors App\Services\Pos\CartCalculator so the screen total matches what the server stores.
  factory CartTotals.calculate(List<CartItem> items, DiscountType? discountType, double discountValue, double taxRate) {
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.total);

    final discountAmount = switch (discountType) {
      DiscountType.percent => (subtotal * discountValue.clamp(0, 100) / 100).round(),
      DiscountType.amount => discountValue.round().clamp(0, subtotal),
      null => 0,
    };

    final taxable = subtotal - discountAmount;
    final taxAmount = (taxable * taxRate / 100).round();

    return CartTotals(subtotal: subtotal, discountAmount: discountAmount, taxAmount: taxAmount, total: taxable + taxAmount);
  }

  final int subtotal;
  final int discountAmount;
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
      prescriptionDraft: json['prescriptionDraft'] is Map<String, dynamic> ? PrescriptionDraft.fromJson(json['prescriptionDraft'] as Map<String, dynamic>) : null,
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

  bool get isEmpty => items.isEmpty;

  bool get needsPrescription => items.any((item) => item.requiresPrescription);

  bool get hasPrescription => prescription != null || prescriptionDraft != null;

  double get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartTotals totals(double taxRate) => CartTotals.calculate(items, discountType, discountValue, taxRate);

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
  }) =>
      Cart(
        clientUuid: clientUuid ?? this.clientUuid,
        items: items ?? this.items,
        customer: clearCustomer ? null : customer ?? this.customer,
        discountType: clearDiscount ? null : discountType ?? this.discountType,
        discountValue: clearDiscount ? 0 : discountValue ?? this.discountValue,
        note: note ?? this.note,
        prescription: clearPrescription ? null : prescription ?? this.prescription,
        prescriptionDraft: clearPrescription ? null : prescriptionDraft ?? this.prescriptionDraft,
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
        'total': ?total,
      };
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
  const HeldOrder({required this.id, this.label, required this.itemCount, required this.total, required this.createdAt, this.cart});

  factory HeldOrder.fromJson(Map<String, dynamic> json) => HeldOrder(
        id: json['id'] as int,
        label: json['label'] as String?,
        itemCount: _double(json['item_count']),
        total: _int(json['total']),
        createdAt: DateTime.parse(json['created_at'] as String),
        cart: json['cart'] as Map<String, dynamic>?,
      );

  final int id;
  final String? label;
  final double itemCount;
  final int total;
  final DateTime createdAt;
  final Map<String, dynamic>? cart;
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
