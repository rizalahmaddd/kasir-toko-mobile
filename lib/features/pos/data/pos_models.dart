int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class PaymentMethodOption {
  const PaymentMethodOption({required this.value, required this.label});

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) =>
      PaymentMethodOption(value: json['value'] as String, label: json['label'] as String);

  final String value;
  final String label;

  bool get isCash => value == 'cash';
}

class PosConfig {
  const PosConfig({
    required this.taxRate,
    required this.taxLabel,
    required this.allowNegativeStock,
    required this.allowCredit,
    required this.canDiscount,
    required this.receiptWidth,
    required this.quickCash,
    required this.paymentMethods,
    required this.qrisEnabled,
    required this.hasOpenShift,
    required this.heldOrdersCount,
  });

  factory PosConfig.fromJson(Map<String, dynamic> json) => PosConfig(
        taxRate: _double(json['tax_rate']),
        taxLabel: json['tax_label'] as String? ?? 'Pajak',
        allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
        allowCredit: json['allow_credit'] as bool? ?? false,
        canDiscount: json['can_discount'] as bool? ?? false,
        receiptWidth: '${json['receipt_width'] ?? '58'}',
        quickCash: (json['quick_cash'] as List? ?? const []).map(_int).toList(),
        paymentMethods: (json['payment_methods'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(PaymentMethodOption.fromJson)
            .toList(),
        qrisEnabled: json['qris_enabled'] as bool? ?? false,
        hasOpenShift: json['has_open_shift'] as bool? ?? false,
        heldOrdersCount: _int(json['held_orders_count']),
      );

  final double taxRate;
  final String taxLabel;
  final bool allowNegativeStock;
  final bool allowCredit;
  final bool canDiscount;
  final String receiptWidth;
  final List<int> quickCash;
  final List<PaymentMethodOption> paymentMethods;
  final bool qrisEnabled;
  final bool hasOpenShift;
  final int heldOrdersCount;
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
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        unit: json['unit'] as String? ?? 'pcs',
        price: _int(json['price']),
        trackStock: json['track_stock'] as bool? ?? false,
        stock: _double(json['stock']),
        isLowStock: json['is_low_stock'] as bool? ?? false,
        categoryName: (json['category'] as Map<String, dynamic>?)?['name'] as String?,
        categoryId: (json['category'] as Map<String, dynamic>?)?['id'] as int?,
        imageUrl: json['image_url'] as String?,
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

  bool get isOutOfStock => trackStock && stock <= 0;
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
  });

  factory CartItem.fromProduct(Product product, {double quantity = 1}) => CartItem(
        productId: product.id,
        name: product.name,
        sku: product.sku,
        unit: product.unit,
        price: product.price,
        quantity: quantity,
        trackStock: product.trackStock,
        stock: product.stock,
      );

  /// Same keys as the web cashier's cart so held orders resume on either device.
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: _int(json['product_id']),
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        unit: json['unit'] as String? ?? 'pcs',
        price: _int(json['price']),
        quantity: _double(json['quantity']),
        discount: _int(json['discount']),
        note: json['note'] as String?,
        trackStock: json['track'] as bool? ?? false,
        stock: _double(json['stock']),
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

  int get gross => (price * quantity).round();

  int get appliedDiscount => discount.clamp(0, gross);

  int get total => gross - appliedDiscount;

  bool get exceedsStock => trackStock && quantity > stock;

  CartItem copyWith({int? price, double? quantity, int? discount, String? note, bool clearNote = false, double? stock}) => CartItem(
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
      };

  Map<String, dynamic> toCheckoutJson() => {
        'product_id': productId,
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
  });

  factory Cart.fromJson(Map<String, dynamic> json, {required String fallbackUuid}) {
    final customer = json['customer'] as Map<String, dynamic>?;

    return Cart(
      clientUuid: json['client_uuid'] as String? ?? fallbackUuid,
      items: (json['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(CartItem.fromJson).toList(),
      customer: customer?['id'] == null ? null : CustomerOption(id: _int(customer!['id']), name: customer['name'] as String? ?? ''),
      discountType: switch (json['discountType']) {
        'percent' => DiscountType.percent,
        'amount' => DiscountType.amount,
        _ => null,
      },
      discountValue: _double(json['discountValue']),
      note: json['note'] as String?,
    );
  }

  final String clientUuid;
  final List<CartItem> items;
  final CustomerOption? customer;
  final DiscountType? discountType;
  final double discountValue;
  final String? note;

  bool get isEmpty => items.isEmpty;

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
  }) =>
      Cart(
        clientUuid: clientUuid ?? this.clientUuid,
        items: items ?? this.items,
        customer: clearCustomer ? null : customer ?? this.customer,
        discountType: clearDiscount ? null : discountType ?? this.discountType,
        discountValue: clearDiscount ? 0 : discountValue ?? this.discountValue,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson({int? total}) => {
        'client_uuid': clientUuid,
        'items': items.map((item) => item.toJson()).toList(),
        'customer': customer == null ? null : {'id': customer!.id, 'name': customer!.name},
        'discountType': discountType?.name,
        'discountValue': discountValue,
        'note': note,
        'total': ?total,
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
