int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class SelfOrderLine {
  const SelfOrderLine({required this.name, required this.quantity, this.modifiers = const [], this.note});

  factory SelfOrderLine.fromJson(Map<String, dynamic> json) => SelfOrderLine(
        name: json['name'] as String? ?? '',
        quantity: _double(json['quantity']),
        modifiers: (json['modifiers'] as List? ?? const []).map((m) => '$m').toList(),
        note: json['note'] as String?,
      );

  final String name;
  final double quantity;
  final List<String> modifiers;
  final String? note;
}

/// Langkah kasir berikutnya untuk sebuah pesanan QR (`next_action` dari server).
abstract final class SelfOrderActions {
  static const accept = 'accept';
  static const pay = 'pay';
  static const verify = 'verify';
  static const decide = 'decide';
}

abstract final class SelfOrderStatuses {
  static const pending = 'pending';
  static const inKitchen = 'in_kitchen';
  static const ready = 'ready';
}

/// Pesanan yang dikirim pelanggan dari QR meja atau standee, seperti tampil di kotak masuk kasir.
class SelfOrder {
  const SelfOrder({
    required this.id,
    required this.number,
    required this.label,
    required this.customerName,
    this.customerPhone,
    required this.status,
    required this.statusLabel,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentLabel,
    this.nextAction,
    required this.total,
    this.notes,
    this.tableLabel,
    required this.items,
    required this.createdAt,
  });

  factory SelfOrder.fromJson(Map<String, dynamic> json) => SelfOrder(
        id: _int(json['id']),
        number: json['number'] as String? ?? '',
        label: json['label'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        status: json['status'] as String? ?? SelfOrderStatuses.pending,
        statusLabel: json['status_label'] as String? ?? '',
        paymentMethod: json['payment_method'] as String? ?? 'cashier',
        paymentStatus: json['payment_status'] as String? ?? 'unpaid',
        paymentLabel: json['payment_label'] as String? ?? '',
        nextAction: json['next_action'] as String?,
        total: _int(json['total']),
        notes: json['notes'] as String?,
        tableLabel: json['table_label'] as String?,
        items: (json['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(SelfOrderLine.fromJson).toList(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  final int id;
  final String number;
  final String label;
  final String customerName;
  final String? customerPhone;
  final String status;
  final String statusLabel;
  final String paymentMethod;
  final String paymentStatus;
  final String paymentLabel;
  final String? nextAction;
  final int total;
  final String? notes;
  final String? tableLabel;
  final List<SelfOrderLine> items;
  final DateTime createdAt;

  bool get isPending => status == SelfOrderStatuses.pending;

  bool get isReady => status == SelfOrderStatuses.ready;

  bool get isQris => paymentMethod == 'qris';

  bool get isPaid => paymentStatus == 'paid';

  bool get isDineIn => tableLabel != null && tableLabel!.isNotEmpty;

  /// Butuh tindakan kasir atau pelayan sekarang; dipakai untuk angka di lencana.
  bool get needsAttention => nextAction != null || isReady;
}
