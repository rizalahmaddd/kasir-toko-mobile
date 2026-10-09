int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

abstract final class OrderStatuses {
  static const fresh = 'new';
  static const inProgress = 'in_progress';
  static const ready = 'ready';
  static const pickedUp = 'picked_up';
  static const cancelled = 'cancelled';

  static const editable = [fresh, inProgress, ready];
}

class OrderItem {
  const OrderItem({required this.name, this.productId, required this.quantity, required this.price, this.note});

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        name: json['name'] as String? ?? '',
        productId: json['product_id'] == null ? null : _int(json['product_id']),
        quantity: _double(json['quantity']),
        price: _int(json['price']),
        note: json['note'] as String?,
      );

  final String name;
  final int? productId;
  final double quantity;
  final int price;
  final String? note;
}

class OrderPayment {
  const OrderPayment({required this.kind, required this.method, required this.amount, required this.paidAt});

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        kind: json['kind'] as String? ?? 'deposit',
        method: json['method'] as String? ?? 'cash',
        amount: _int(json['amount']),
        paidAt: DateTime.parse(json['paid_at'] as String),
      );

  final String kind;
  final String method;
  final int amount;
  final DateTime paidAt;
}

/// Pesanan (pre-order) atau tiket servis; dilunasi lewat kasir.
class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.number,
    required this.type,
    required this.status,
    required this.statusLabel,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.pickupAt,
    required this.estimatedTotal,
    required this.deposit,
    required this.remaining,
    this.device,
    this.deviceSerial,
    this.complaint,
    this.notes,
    this.saleId,
    this.items = const [],
    this.payments = const [],
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) => CustomerOrder(
        id: _int(json['id']),
        number: json['number'] as String? ?? '',
        type: json['type'] as String? ?? 'order',
        status: json['status'] as String? ?? OrderStatuses.fresh,
        statusLabel: json['status_label'] as String? ?? '',
        customerId: json['customer_id'] == null ? null : _int(json['customer_id']),
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        pickupAt: json['pickup_at'] == null ? null : DateTime.parse(json['pickup_at'] as String).toLocal(),
        estimatedTotal: _int(json['estimated_total']),
        deposit: _int(json['deposit']),
        remaining: _int(json['remaining']),
        device: json['device'] as String?,
        deviceSerial: json['device_serial'] as String?,
        complaint: json['complaint'] as String?,
        notes: json['notes'] as String?,
        saleId: json['sale_id'] == null ? null : _int(json['sale_id']),
        items: (json['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(OrderItem.fromJson).toList(),
        payments: (json['payments'] as List? ?? const []).cast<Map<String, dynamic>>().map(OrderPayment.fromJson).toList(),
      );

  final int id;
  final String number;
  final String type;
  final String status;
  final String statusLabel;
  final int? customerId;
  final String customerName;
  final String? customerPhone;
  final DateTime? pickupAt;
  final int estimatedTotal;
  final int deposit;
  final int remaining;
  final String? device;
  final String? deviceSerial;
  final String? complaint;
  final String? notes;
  final int? saleId;
  final List<OrderItem> items;
  final List<OrderPayment> payments;

  bool get isService => type == 'service';

  bool get isOpen => status != OrderStatuses.pickedUp && status != OrderStatuses.cancelled;
}

/// Isi keranjang pelunasan dari server.
class OrderCart {
  const OrderCart({required this.orderId, required this.number, required this.deposit, this.customerId, this.customerName, required this.items, required this.skipped});

  factory OrderCart.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;

    return OrderCart(
      orderId: _int(json['customer_order_id']),
      number: json['number'] as String? ?? '',
      deposit: _int(json['deposit']),
      customerId: customer == null ? null : _int(customer['id']),
      customerName: customer?['name'] as String?,
      items: [
        for (final item in (json['items'] as List? ?? const []).cast<Map<String, dynamic>>())
          (productId: _int(item['product_id']), quantity: _double(item['quantity']), note: item['note'] as String?),
      ],
      skipped: (json['skipped'] as List? ?? const []).map((s) => '$s').toList(),
    );
  }

  final int orderId;
  final String number;
  final int deposit;
  final int? customerId;
  final String? customerName;
  final List<({int productId, double quantity, String? note})> items;
  final List<String> skipped;
}
