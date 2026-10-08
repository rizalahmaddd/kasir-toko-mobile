import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../kitchen/data/kitchen_models.dart';

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime _date(dynamic value) => DateTime.parse(value as String);

DateTime? _dateOrNull(dynamic value) => value == null ? null : DateTime.parse(value as String);

class SaleCustomer {
  const SaleCustomer({required this.id, required this.name, this.phone});

  factory SaleCustomer.fromJson(Map<String, dynamic> json) =>
      SaleCustomer(id: json['id'] as int, name: json['name'] as String, phone: json['phone'] as String?);

  final int id;
  final String name;
  final String? phone;
}

class SaleItem {
  const SaleItem({
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.discountAmount,
    required this.total,
    this.note,
    this.modifiers = const [],
    this.serials = const [],
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productName: json['product_name'] as String,
        unit: json['unit'] as String? ?? '',
        quantity: _double(json['quantity']),
        price: _int(json['price']),
        discountAmount: _int(json['discount_amount']),
        total: _int(json['total']),
        note: json['note'] as String?,
        modifiers: (json['modifiers'] as List? ?? const []).cast<Map<String, dynamic>>().map((m) => m['name'] as String? ?? '').where((n) => n.isNotEmpty).toList(),
        serials: (json['serials'] as List? ?? const []).map((s) => '$s').toList(),
      );

  final String productName;
  final String unit;
  final double quantity;
  final int price;
  final int discountAmount;
  final int total;
  final String? note;
  final List<String> modifiers;
  final List<String> serials;
}

class DeliveryNoteInfo {
  const DeliveryNoteInfo({required this.id, required this.number, required this.recipient, required this.address, required this.status, this.phone, this.project, this.driver, this.vehicle});

  factory DeliveryNoteInfo.fromJson(Map<String, dynamic> json) => DeliveryNoteInfo(
        id: _int(json['id']),
        number: json['number'] as String? ?? '',
        recipient: json['recipient'] as String? ?? '',
        address: json['address'] as String? ?? '',
        status: json['status'] as String? ?? 'sent',
        phone: json['phone'] as String?,
        project: json['project'] as String?,
        driver: json['driver'] as String?,
        vehicle: json['vehicle'] as String?,
      );

  final int id;
  final String number;
  final String recipient;
  final String address;
  final String status;
  final String? phone;
  final String? project;
  final String? driver;
  final String? vehicle;

  bool get isDelivered => status == 'delivered';
}

class SalePayment {
  const SalePayment({
    required this.kind,
    required this.method,
    required this.methodLabel,
    required this.amount,
    this.reference,
    required this.paidAt,
    this.cashierName,
  });

  factory SalePayment.fromJson(Map<String, dynamic> json) => SalePayment(
        kind: json['kind'] as String? ?? PaymentKinds.sale,
        method: json['method'] as String,
        methodLabel: json['method_label'] as String,
        amount: _int(json['amount']),
        reference: json['reference'] as String?,
        paidAt: _date(json['paid_at']),
        cashierName: (json['user'] as Map<String, dynamic>?)?['name'] as String?,
      );

  final String kind;
  final String method;
  final String methodLabel;
  final int amount;
  final String? reference;
  final DateTime paidAt;
  final String? cashierName;
}

class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.soldAt,
    required this.cashierName,
    this.customer,
    required this.itemsCount,
    required this.total,
    this.paidAmount = 0,
    required this.dueAmount,
    required this.paymentMethods,
    this.outletName,
  });

  factory SaleSummary.fromJson(Map<String, dynamic> json) => SaleSummary(
        id: json['id'] as int,
        number: json['number'] as String,
        status: json['status'] as String,
        statusLabel: json['status_label'] as String,
        soldAt: _date(json['sold_at']),
        cashierName: (json['cashier'] as Map<String, dynamic>?)?['name'] as String? ?? '-',
        customer: json['customer'] == null ? null : SaleCustomer.fromJson(json['customer'] as Map<String, dynamic>),
        itemsCount: _int(json['items_count']),
        total: _int(json['total']),
        paidAmount: _int(json['paid_amount']),
        dueAmount: _int(json['due_amount']),
        paymentMethods: (json['payment_methods'] as List? ?? const []).cast<String>(),
        outletName: (json['outlet'] as Map<String, dynamic>?)?['name'] as String?,
      );

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final DateTime soldAt;
  final String cashierName;
  final String? outletName;
  final SaleCustomer? customer;
  final int itemsCount;
  final int total;
  final int paidAmount;
  final int dueAmount;
  final List<String> paymentMethods;

  bool get isVoided => status == SaleStatuses.voided;
}

class SaleDetail {
  const SaleDetail({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.soldAt,
    required this.cashierName,
    this.customer,
    required this.subtotal,
    required this.discountAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.paidAmount,
    required this.cashReceived,
    required this.changeAmount,
    required this.dueAmount,
    this.note,
    required this.items,
    required this.payments,
    this.voidedAt,
    this.voidReason,
    this.whatsappUrl,
    required this.canVoid,
    this.canCollectPayment = false,
    this.discountType,
    this.discountValue = 0,
    this.shiftNumber,
    this.outletId,
    this.outletName,
    this.flagLabels = const [],
    this.prescriptionNumber,
    this.prescriptionDoctor,
    this.serviceChargeRate = 0,
    this.serviceChargeAmount = 0,
    this.orderTypeLabel,
    this.tableLabel,
    this.queueNumber,
    this.deliveryNotes = const [],
    this.customerOrderNumber,
    this.kitchenTickets = const [],
  });

  factory SaleDetail.fromJson(Map<String, dynamic> json) {
    final abilities = json['abilities'] as Map<String, dynamic>? ?? const {};

    return SaleDetail(
      id: json['id'] as int,
      number: json['number'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      soldAt: _date(json['sold_at']),
      cashierName: (json['cashier'] as Map<String, dynamic>?)?['name'] as String? ?? '-',
      customer: json['customer'] == null ? null : SaleCustomer.fromJson(json['customer'] as Map<String, dynamic>),
      subtotal: _int(json['subtotal']),
      discountAmount: _int(json['discount_amount']),
      taxRate: _double(json['tax_rate']),
      taxAmount: _int(json['tax_amount']),
      total: _int(json['total']),
      paidAmount: _int(json['paid_amount']),
      cashReceived: _int(json['cash_received']),
      changeAmount: _int(json['change_amount']),
      dueAmount: _int(json['due_amount']),
      note: json['note'] as String?,
      items: (json['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(SaleItem.fromJson).toList(),
      payments: (json['payments'] as List? ?? const []).cast<Map<String, dynamic>>().map(SalePayment.fromJson).toList(),
      voidedAt: _dateOrNull(json['voided_at']),
      voidReason: json['void_reason'] as String?,
      whatsappUrl: json['whatsapp_url'] as String?,
      canVoid: abilities['void'] as bool? ?? false,
      canCollectPayment: abilities['collect_payment'] as bool? ?? false,
      discountType: json['discount_type'] as String?,
      discountValue: _double(json['discount_value']),
      shiftNumber: (json['shift'] as Map<String, dynamic>?)?['number'] as String?,
      outletId: (json['outlet'] as Map<String, dynamic>?)?['id'] as int?,
      outletName: (json['outlet'] as Map<String, dynamic>?)?['name'] as String?,
      flagLabels: (json['flag_labels'] as List? ?? const []).cast<String>(),
      prescriptionNumber: (json['prescription'] as Map<String, dynamic>?)?['number'] as String?,
      prescriptionDoctor: (json['prescription'] as Map<String, dynamic>?)?['doctor_name'] as String?,
      serviceChargeRate: _double(json['service_charge_rate']),
      serviceChargeAmount: _int(json['service_charge_amount']),
      orderTypeLabel: json['order_type_label'] as String?,
      tableLabel: json['table_label'] as String?,
      queueNumber: json['queue_number'] == null ? null : _int(json['queue_number']),
      deliveryNotes: (json['delivery_notes'] as List? ?? const []).cast<Map<String, dynamic>>().map(DeliveryNoteInfo.fromJson).toList(),
      customerOrderNumber: (json['customer_order'] as Map<String, dynamic>?)?['number'] as String?,
      kitchenTickets: (json['kitchen_tickets'] as List? ?? const []).cast<Map<String, dynamic>>().map(KitchenTicket.fromJson).toList(),
    );
  }

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final DateTime soldAt;
  final String cashierName;
  final int? outletId;
  final String? outletName;
  final SaleCustomer? customer;
  final int subtotal;
  final int discountAmount;
  final double taxRate;
  final int taxAmount;
  final int total;
  final int paidAmount;
  final int cashReceived;
  final int changeAmount;
  final int dueAmount;
  final String? note;
  final List<SaleItem> items;
  final List<SalePayment> payments;
  final DateTime? voidedAt;
  final String? voidReason;
  final String? whatsappUrl;
  final bool canVoid;
  final bool canCollectPayment;
  final String? discountType;
  final double discountValue;
  final String? shiftNumber;

  /// Catatan transaksi offline yang perlu ditinjau (resep belum diverifikasi, batch kedaluwarsa, dll.).
  final List<String> flagLabels;
  final String? prescriptionNumber;
  final String? prescriptionDoctor;
  final double serviceChargeRate;
  final int serviceChargeAmount;
  final String? orderTypeLabel;
  final String? tableLabel;
  final int? queueNumber;
  final List<DeliveryNoteInfo> deliveryNotes;
  final String? customerOrderNumber;
  final List<KitchenTicket> kitchenTickets;


  /// Mis. "Dine-in · Meja 5" atau "Bawa Pulang · Antrean 012".
  String? get orderLabel {
    if (orderTypeLabel == null) {
      return null;
    }
    final marker = tableLabel != null ? 'Meja $tableLabel' : (queueNumber != null ? 'Antrean ${queueNumber.toString().padLeft(3, '0')}' : null);

    return [orderTypeLabel!, ?marker].join(' · ');
  }


  bool get isVoided => status == SaleStatuses.voided;
}

class Receipt {
  const Receipt({required this.number, required this.text, this.whatsappUrl, required this.paperWidth});

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        number: json['number'] as String,
        text: json['text'] as String,
        whatsappUrl: json['whatsapp_url'] as String?,
        paperWidth: '${json['paper_width'] ?? '58'}',
      );

  final String number;
  final String text;
  final String? whatsappUrl;
  final String paperWidth;
}

class SalesPage {
  const SalesPage({required this.items, required this.hasMore, required this.page, required this.count, required this.total, required this.voided});

  final List<SaleSummary> items;
  final bool hasMore;
  final int page;
  final int count;
  final int total;
  final int voided;
}
