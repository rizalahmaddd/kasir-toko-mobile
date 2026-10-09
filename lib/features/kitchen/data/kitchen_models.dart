int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class KitchenTicketItem {
  const KitchenTicketItem({required this.name, required this.quantity, this.unit = '', this.modifiers = const [], this.note});

  factory KitchenTicketItem.fromJson(Map<String, dynamic> json) => KitchenTicketItem(
        name: json['name'] as String? ?? '',
        quantity: _double(json['quantity']),
        unit: json['unit'] as String? ?? '',
        modifiers: (json['modifiers'] as List? ?? const []).map((m) => '$m').toList(),
        note: json['note'] as String?,
      );

  final String name;
  final double quantity;
  final String unit;
  final List<String> modifiers;
  final String? note;
}

/// Tiket dapur tanpa harga: snapshot menu yang harus disiapkan.
class KitchenTicket {
  const KitchenTicket({required this.id, required this.label, this.orderTypeLabel, required this.status, required this.items, this.saleNumber, this.cashier, required this.createdAt});

  factory KitchenTicket.fromJson(Map<String, dynamic> json) => KitchenTicket(
        id: _int(json['id']),
        label: json['label'] as String? ?? '',
        orderTypeLabel: json['order_type_label'] as String?,
        status: json['status'] as String? ?? 'pending',
        items: (json['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(KitchenTicketItem.fromJson).toList(),
        saleNumber: json['sale_number'] as String?,
        cashier: json['cashier'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  final int id;
  final String label;
  final String? orderTypeLabel;
  final String status;
  final List<KitchenTicketItem> items;
  final String? saleNumber;
  final String? cashier;
  final DateTime createdAt;

  bool get isDone => status == 'done';
}
